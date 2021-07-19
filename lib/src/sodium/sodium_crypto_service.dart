import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/crypto/crypto_service.dart';
import 'package:firebase_sync/src/sodium/sodium_key_manager.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';
import 'package:sodium/sodium.dart';

part 'sodium_crypto_service.freezed.dart';
part 'sodium_crypto_service.g.dart';

class SodiumCryptoService implements CryptoService {
  final Sodium sodium;
  final SodiumKeyManager keyManager;

  SodiumCryptoService({
    required this.sodium,
    required this.keyManager,
  });

  @override
  String keyHash({
    required String storeName,
    required String key,
  }) {
    final hashingKey = keyManager.keyHashingKey(
      storeName: storeName,
      keyBytes: sodium.crypto.genericHash.keyBytesMax,
    );
    try {
      final hash = sodium.crypto.genericHash(
        key: hashingKey,
        outLen: sodium.crypto.genericHash.bytesMax,
        message: key.toCharArray().unsignedView(),
      );
      return base64Url.encode(hash);
    } finally {
      hashingKey.dispose();
    }
  }

  @override
  Future<MapEntry<String, CipherMessage>> encrypt({
    required String storeName,
    required CryptoFirebaseStore store,
    required String key,
    required dynamic dataJson,
    String? hashedKey,
  }) {
    final encryptionKey = keyManager.remoteEncryptionKey(
      storeName: storeName,
      keyBytes: sodium.crypto.aead.keyBytes,
    );
    try {
      hashedKey ??= keyHash(storeName: storeName, key: key);
      final nonce = sodium.randombytes.buf(sodium.crypto.aead.nonceBytes);

      final cipherData = sodium.crypto.aead.encryptDetached(
        message: _PlainCryptoData(
          key: key,
          data: dataJson,
        ).toBytes(),
        additionalData: _buildPath(store, hashedKey),
        nonce: nonce,
        key: encryptionKey.value,
      );

      return Future.value(
        MapEntry(
          hashedKey,
          CipherMessage(
            cipherText: cipherData.cipherText,
            mac: cipherData.mac,
            nonce: nonce,
            keyId: encryptionKey.key,
          ),
        ),
      );
    } finally {
      encryptionKey.value.dispose();
    }
  }

  @override
  Future<MapEntry<String, dynamic>> decrypt({
    required String storeName,
    required CryptoFirebaseStore store,
    required String hashedKey,
    required CipherMessage data,
  }) async {
    final encryptionKey = await keyManager.remoteEncryptionKeyForId(
      storeName: storeName,
      keyId: data.keyId,
      keyBytes: sodium.crypto.aead.keyBytes,
    );
    try {
      final plainData = _PlainCryptoData.fromBytes(
        sodium.crypto.aead.decryptDetached(
          cipherText: data.cipherText,
          additionalData: _buildPath(store, hashedKey),
          mac: data.mac,
          nonce: data.nonce,
          key: encryptionKey,
        ),
      );

      return MapEntry<String, dynamic>(plainData.key, plainData.data);
    } finally {
      encryptionKey.dispose();
    }
  }

  Uint8List _buildPath(CryptoFirebaseStore store, String keyHash) {
    final entryPath = posix.canonicalize(posix.join(
      posix.separator,
      store.path,
      keyHash,
    ));
    final entryUri = Uri(scheme: store.restApi.database, path: entryPath);
    return entryUri.toString().toCharArray().unsignedView();
  }
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

  Uint8List toBytes() => json.encode(this).toCharArray().unsignedView();
}
