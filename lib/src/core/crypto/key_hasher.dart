import 'package:meta/meta.dart';

abstract class KeyHasher {
  const KeyHasher._(); // coverage:ignore-line

  String hashKey({
    required String storeName,
    required String plainKey,
  });
}

@sealed
class StoreBoundKeyHasher {
  final String storeName;
  final KeyHasher keyHasher;

  const StoreBoundKeyHasher({
    required this.storeName,
    required this.keyHasher,
  });

  String hashKey(String plainKey) => keyHasher.hashKey(
        storeName: storeName,
        plainKey: plainKey,
      );
}
