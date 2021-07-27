abstract class KeyManager<TKey extends Object> {
  const KeyManager._(); // coverage:ignore-line

  TKey localEncryptionKey({
    required String storeName,
    required int keyBytes,
  });

  TKey keyHashingKey({
    required String storeName,
    required int keyBytes,
  });

  MapEntry<int, TKey> remoteEncryptionKey({
    required String storeName,
    required int keyBytes,
  });

  Future<TKey> remoteEncryptionKeyForId({
    required String storeName,
    required int keyId,
    required int keyBytes,
  });
}
