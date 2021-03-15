import 'dart:async';

import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import 'hive_transaction.dart';

abstract class HiveStorageBase<T extends Object> implements Storage<T> {
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
  Future<void> deleteEntries(Iterable<String> keys) async =>
      _boxAwait(box.deleteAll(keys));

  @override
  Future<void> deleteEntry(String key) async => _boxAwait(box.delete(key));

  @override
  FutureOr<List<String>> keys() =>
      box.keys.cast<String>().toList(growable: false);

  @override
  FutureOr<int> length() => box.length;

  @override
  FutureOr<Stream<LocalStoreEvent<T>>> watch() => box.watch().map((event) {
        if (event.deleted) {
          return LocalStoreEvent.delete(event.key as String);
        } else {
          return LocalStoreEvent.update(event.key as String, event.value as T);
        }
      });

  @override
  FutureOr<Stream<T?>> watchEntry(String key) => box
      .watch(key: key)
      .where((event) => event.key == key)
      .map((event) => event.value as T?);

  @override
  Future<void> writeEntries(Map<String, T> entries) async =>
      _boxAwait(box.putAll(entries));

  @override
  Future<void> writeEntry(String key, T value) async =>
      _boxAwait(box.put(key, value));

  @override
  Future<void> transaction(TransactionFn<T> transaction) async =>
      HiveTransaction(this).call(transaction);

  FutureOr<void> _boxAwait(Future<dynamic> future) {
    if (awaitBoxOperations) {
      // ignore: unnecessary_cast
      return future as Future<void>;
    }
  }
}
