abstract class KeyHasher {
  const KeyHasher._();

  String hashKey({
    required String storeName,
    required String key,
  });
}

class StoreBoundKeyHasher {
  final String storeName;
  final KeyHasher keyHasher;

  const StoreBoundKeyHasher({
    required this.storeName,
    required this.keyHasher,
  });

  String hashKey(String key) => keyHasher.hashKey(
        storeName: storeName,
        key: key,
      );
}
