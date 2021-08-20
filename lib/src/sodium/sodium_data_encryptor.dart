import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import '../core/crypto/cipher_message.dart';
import '../core/crypto/data_encryptor.dart';
import 'sodium_key_manager.dart';

class SodiumDataEncryptor implements DataEncryptor {
  final Sodium sodium;
  final SodiumKeyManager keyManager;

  final int storeId;

  final _remoteKeys = <int, SecureKey>{};

  SodiumDataEncryptor({
    required this.sodium,
    required this.keyManager,
    required this.storeId,
  });

  @override
  void dispose() {
    for (final key in _remoteKeys.values) {
      key.dispose();
    }
  }

  @override
  Future<CipherMessage> encrypt({
    required Uri remoteUri,
    required dynamic dataJson,
  }) async {
    final keyId = keyManager.currentRemoteKeyId;
    final encryptionKey = await _loadKey(keyId);
    final nonce = sodium.randombytes.buf(sodium.crypto.aead.nonceBytes);
    final remoteTag = sodium.randombytes.buf(CipherMessage.remoteTagSize);

    final cipherData = sodium.crypto.aead.encryptDetached(
      message: _jsonToBytes(dataJson),
      additionalData: _buildPath(
        remoteUri: remoteUri,
        remoteTag: remoteTag,
      ),
      nonce: nonce,
      key: encryptionKey,
    );

    return CipherMessage(
      cipherText: cipherData.cipherText,
      mac: cipherData.mac,
      nonce: nonce,
      remoteTag: remoteTag,
      keyId: keyId,
    );
  }

  @override
  Future<dynamic> decrypt({
    required Uri remoteUri,
    required CipherMessage data,
  }) async =>
      _bytesToJson(
        sodium.crypto.aead.decryptDetached(
          cipherText: data.cipherText,
          additionalData: _buildPath(
            remoteUri: remoteUri,
            remoteTag: data.remoteTag,
          ),
          mac: data.mac,
          nonce: data.nonce,
          key: await _loadKey(data.keyId),
        ),
      );

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

  Future<SecureKey> _loadKey(int keyId) async =>
      _remoteKeys[keyId] ??= await keyManager.remoteEncryptionKey(
        keyId: keyId,
        storeId: storeId,
        keyBytes: sodium.crypto.aead.keyBytes,
      );
}
