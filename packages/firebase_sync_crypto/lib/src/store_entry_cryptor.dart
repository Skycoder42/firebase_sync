import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart';

import 'crypto_data.dart';
import 'key_management/key_manager.dart';

class UnknownKeyException implements Exception {
  final String keyId;

  const UnknownKeyException(this.keyId);

  @override
  String toString() => 'Unable to find a key for id: $keyId';
}

class StoreEntryCryptor {
  final KeyManager keyManager;
  final StreamingCipher streamingCipher;

  StoreEntryCryptor(this.keyManager) : streamingCipher = AesGcm.with256bits();

  const StoreEntryCryptor.withCipher({
    required this.keyManager,
    required this.streamingCipher,
  });

  Future<CryptoData> encrypt({
    required dynamic jsonData,
    required Iterable<String> keyPath,
  }) async {
    final keyInfo = await keyManager.obtainKey();
    final cipherBox = await streamingCipher.encrypt(
      utf8.encode(json.encode(jsonData)),
      secretKey: keyInfo.secretKey,
      aad: _normalizedKeyPathBytes(keyPath),
    );
    return CryptoData.fromSecretBox(cipherBox, keyInfo.keyId);
  }

  Future<dynamic> decrypt({
    required CryptoData cryptoData,
    required Iterable<String> keyPath,
  }) async {
    final keyInfo = await keyManager.obtainKeyForId(cryptoData.keyId);
    if (keyInfo == null) {
      throw UnknownKeyException(cryptoData.keyId);
    }

    final plainBytes = await streamingCipher.decrypt(
      cryptoData.toSecretBox(),
      secretKey: keyInfo.secretKey,
      aad: _normalizedKeyPathBytes(keyPath),
    );
    return json.decode(utf8.decode(plainBytes));
  }

  List<int> _normalizedKeyPathBytes(Iterable<String> keyPath) =>
      utf8.encode(posix.canonicalize(keyPath.join(posix.separator)));
}
