import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sodium/sodium.dart';

import '../core/crypto/cipher_message.dart';
import '../core/crypto/data_encryptor.dart';
import 'sodium_key_manager.dart';

part 'sodium_data_encryptor.freezed.dart';
part 'sodium_data_encryptor.g.dart';

class SodiumDataEncryptor implements DataEncryptor {
  final Sodium sodium;
  final SodiumKeyManager keyManager;

  SodiumDataEncryptor({
    required this.sodium,
    required this.keyManager,
  });

  @override
  Uint8List generateRandom(int length) => sodium.randombytes.buf(length);

  @override
  Future<CipherMessage> encrypt({
    required String storeName,
    required Uri remoteUri,
    required dynamic dataJson,
    String? plainKey,
  }) {
    final encryptionKey = keyManager.remoteEncryptionKey(
      storeName: storeName,
      keyBytes: sodium.crypto.aead.keyBytes,
    );
    try {
      final nonce = sodium.randombytes.buf(sodium.crypto.aead.nonceBytes);
      final remoteTag = sodium.randombytes.buf(CipherMessage.remoteTagSize);

      // wrap data with key, if required
      final dynamic plainData;
      if (plainKey != null) {
        plainData = _PlainCryptoData(
          key: plainKey,
          data: dataJson,
        ).toJson();
      } else {
        plainData = dataJson;
      }

      final cipherData = sodium.crypto.aead.encryptDetached(
        message: _jsonToBytes(plainData),
        additionalData: _buildPath(
          remoteUri: remoteUri,
          remoteTag: remoteTag,
        ),
        nonce: nonce,
        key: encryptionKey.value,
      );

      return Future.value(
        CipherMessage(
          cipherText: cipherData.cipherText,
          mac: cipherData.mac,
          nonce: nonce,
          remoteTag: remoteTag,
          keyId: encryptionKey.key,
        ),
      );
    } finally {
      encryptionKey.value.dispose();
    }
  }

  @override
  Future<dynamic> decrypt({
    required String storeName,
    required Uri remoteUri,
    required CipherMessage data,
    bool extractKey = false,
  }) async {
    final encryptionKey = await keyManager.remoteEncryptionKeyForId(
      storeName: storeName,
      keyId: data.keyId,
      keyBytes: sodium.crypto.aead.keyBytes,
    );
    try {
      final dynamic plainData = _bytesToJson(
        sodium.crypto.aead.decryptDetached(
          cipherText: data.cipherText,
          additionalData: _buildPath(
            remoteUri: remoteUri,
            remoteTag: data.remoteTag,
          ),
          mac: data.mac,
          nonce: data.nonce,
          key: encryptionKey,
        ),
      );

      return plainData;
    } finally {
      encryptionKey.dispose();
    }
  }

  Uint8List _buildPath({
    required Uri remoteUri,
    required Uint8List remoteTag,
  }) {
    if (remoteUri.hasFragment) {
      throw ArgumentError.value(
        remoteUri,
        'remoteUri',
        'Must not have a fragment:',
      );
    }

    final entryUri = Uri(
      scheme: remoteUri.hasScheme ? remoteUri.scheme : null,
      host: remoteUri.hasAuthority ? remoteUri.host : null,
      port: remoteUri.hasPort ? remoteUri.port : null,
      userInfo: remoteUri.hasAuthority ? remoteUri.userInfo : null,
      path: remoteUri.hasEmptyPath ? null : remoteUri.path,
      query: remoteUri.hasQuery ? remoteUri.query : null,
      fragment: base64Url.encode(remoteTag),
    );
    return entryUri.toString().toCharArray().unsignedView();
  }

  Uint8List _jsonToBytes(dynamic jsonData) =>
      json.encode(jsonData).toCharArray().unsignedView();

  dynamic _bytesToJson(Uint8List bytes) =>
      json.decode(bytes.signedView().toDartString());
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
}
