import 'dart:async';

import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

abstract class HiveStorageBase<T> implements Storage<T> {
  final BoxBase<T> box;
  final bool awaitBoxOperations;

  const HiveStorageBase({
    required this.box,
    this.awaitBoxOperations = false,
  });

  @override
  Future<void> clear() async => _boxAwait(box.clear());

  @override
  FutureOr<bool> contains(String key) => box.containsKey(key);

  @override
  Future<void> deleteEntry(String key) async => _boxAwait(box.delete(key));

  @override
  FutureOr<List<String>> keys() =>
      box.keys.cast<String>().toList(growable: false);

  @override
  FutureOr<int> length() => box.length;

  @override
  FutureOr<Stream<dynamic>> watch() => box.watch();

  @override
  FutureOr<Stream<dynamic>> watchEntry(String key) => box.watch(key: key);

  @override
  Future<void> writeEntry(String key, T value) async =>
      _boxAwait(box.put(key, value));

  FutureOr<void> _boxAwait(Future<dynamic> future) {
    if (awaitBoxOperations) {
      // ignore: unnecessary_cast
      return future as Future<void>;
    }
  }
}
