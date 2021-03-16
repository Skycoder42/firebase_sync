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
  FutureOr<void> clear() => _boxAwait(box.clear());

  @override
  Future<void> close() => box.close();

  @override
  FutureOr<bool> contains(String key) => box.containsKey(key);

  @override
  FutureOr<void> deleteEntries(Iterable<String> keys) =>
      _boxAwait(box.deleteAll(keys));

  @override
  FutureOr<void> deleteEntry(String key) => _boxAwait(box.delete(key));

  @override
  FutureOr<void> destroy() => _boxAwait(box.deleteFromDisk());

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
  FutureOr<void> writeEntries(Map<String, T> entries) =>
      _boxAwait(box.putAll(entries));

  @override
  FutureOr<void> writeEntry(String key, T value) =>
      _boxAwait(box.put(key, value));

  @override
  FutureOr<void> transaction(TransactionFn<T> transaction) =>
      HiveTransaction(this).call(transaction);

  FutureOr<void> _boxAwait(Future<dynamic> future) {
    if (awaitBoxOperations) {
      // ignore: unnecessary_cast
      return future as Future<void>;
    }
  }
}
