import 'dart:convert';

import 'package:sodium/sodium.dart';

import '../core/crypto/key_hasher.dart';
import 'sodium_key_manager.dart';

class SodiumKeyHasher implements KeyHasher {
  final Sodium sodium;
  final SodiumKeyManager keyManager;

  SodiumKeyHasher({
    required this.sodium,
    required this.keyManager,
  });

  @override
  String hashKey({
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
}
