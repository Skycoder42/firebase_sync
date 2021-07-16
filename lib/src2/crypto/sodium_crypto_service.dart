import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/cipher_message.dart';
import 'package:firebase_sync/src/core/crypto/crypto_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';
import 'package:sodium/sodium.dart';

part 'sodium_crypto_service.freezed.dart';
part 'sodium_crypto_service.g.dart';

@internal
class SodiumCryptoService implements CryptoService {
  final Sodium sodium;
  final SecureKey masterHashKey;
  final SecureKey masterEncryptionKey;

  // TODO handle key rotations!

  SodiumCryptoService({
    required this.sodium,
    required this.masterHashKey,
    required this.masterEncryptionKey,
  });

  @override
  String keyHash(String key) {
    final keyHash = sodium.crypto.genericHash(
      key: hashKey,
      message: key.toUtf8Bytes(),
    );
    return base64Url.encode(keyHash);
  }

  @override
  MapEntry<String, CipherMessage> encrypt({
    required FirebaseStore<dynamic> store,
    required String key,
    required dynamic dataJson,
    String? hashedKey,
  }) {
    hashedKey ??= keyHash(key);
    final nonce = sodium.randombytes.buf(sodium.crypto.aead.nonceBytes);

    final cipherData = sodium.crypto.aead.encryptDetached(
      message: _PlainCryptoData(
        key: key,
        data: dataJson,
      ).toBytes(),
      additionalData: _buildPath(store, hashedKey),
      nonce: nonce,
      key: encryptionKey,
    );

    return MapEntry(
      hashedKey,
      CipherMessage(
        cipherText: cipherData.cipherText,
        mac: cipherData.mac,
        nonce: nonce,
      ),
    );
  }

  @override
  MapEntry<String, dynamic> decrypt({
    required FirebaseStore<dynamic> store,
    required String hashedKey,
    required CipherMessage data,
  }) {
    final plainData = _PlainCryptoData.fromBytes(
      sodium.crypto.aead.decryptDetached(
        cipherText: data.cipherText,
        additionalData: _buildPath(store, hashedKey),
        mac: data.mac,
        nonce: data.nonce,
        key: dataKey,
      ),
    );

    return MapEntry(plainData.key, plainData.data);
  }

  Uint8List _buildPath(FirebaseStore<dynamic> store, String keyHash) {
    final entryPath = posix.canonicalize(posix.join(
      posix.separator,
      store.path,
      keyHash,
    ));
    final entryUri = Uri(scheme: store.restApi.database, path: entryPath);
    return entryUri.toString().toUtf8Bytes();
  }
}

extension _CryptoStringX on String {
  Uint8List toUtf8Bytes() => Uint8List.fromList(utf8.encode(this));
}

@freezed
class _PlainCryptoData with _$_PlainCryptoData {
  const _PlainCryptoData._();

  const factory _PlainCryptoData({
    required String key,
    required dynamic data,
  }) = __PlainCryptoData;

  factory _PlainCryptoData.fromJson(Map<String, dynamic> json) =>
      _$_PlainCryptoDataFromJson(json);

  factory _PlainCryptoData.fromBytes(Uint8List bytes) =>
      _PlainCryptoData.fromJson(
        json.decode(utf8.decode(bytes)) as Map<String, dynamic>,
      );

  Uint8List toBytes() => json.encode(this).toUtf8Bytes();
}
