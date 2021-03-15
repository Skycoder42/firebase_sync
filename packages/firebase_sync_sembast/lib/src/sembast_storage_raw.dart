import 'dart:async';

import 'package:firebase_sync/firebase_sync.dart';
import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';

@internal
class SembastStorageRaw<T extends Object> implements Storage<T> {
  final DatabaseClient databaseClient;
  final StoreRef<String, T> storeRef;

  const SembastStorageRaw.database({
    required Database database,
    required this.storeRef,
  }) : databaseClient = database;

  const SembastStorageRaw.transaction({
    required Transaction transaction,
    required this.storeRef,
  }) : databaseClient = transaction;

  Future<Map<String, T>> query(Finder finder) async {
    final records = await storeRef.find(databaseClient, finder: finder);
    return {
      for (final record in records) record.key: record.value,
    };
  }

  @override
  Future<void> clear() => storeRef.drop(databaseClient);

  @override
  FutureOr<bool> contains(String key) =>
      storeRef.record(key).exists(databaseClient);

  @override
  Future<void> deleteEntries(Iterable<String> keys) =>
      storeRef.records(keys).delete(databaseClient);

  @override
  Future<void> deleteEntry(String key) =>
      storeRef.record(key).delete(databaseClient);

  @override
  FutureOr<Map<String, T>> entries() async {
    final records = await storeRef.find(databaseClient);
    return {
      for (var record in records) record.key: record.value,
    };
  }

  @override
  bool get isSync => false;

  @override
  FutureOr<List<String>> keys() => storeRef.findKeys(databaseClient);

  @override
  FutureOr<int> length() => storeRef.count(databaseClient);

  @override
  FutureOr<T?> readEntry(String key) =>
      storeRef.record(key).get(databaseClient);

  @override
  Future<void> transaction(TransactionFn<T> transactionCallback) {
    if (databaseClient is Database) {
      return (databaseClient as Database).transaction(
        (transaction) => transactionCallback(
          SembastStorageRaw.transaction(
            transaction: transaction,
            storeRef: storeRef,
          ),
        ),
      );
    } else {
      throw StateError('Cannot call transaction from within a transaction');
    }
  }

  // TODO try with query?
  @override
  FutureOr<Stream<LocalStoreEvent<T>>> watch() => throw UnsupportedError(
        'watching the whole database is not supported by sembast',
      );

  @override
  FutureOr<Stream<T?>> watchEntry(String key) => storeRef
      .record(key)
      .onSnapshot(
        databaseClient is Database
            ? databaseClient as Database
            : throw StateError(
                'Cannot call watchEntry from within a transaction',
              ),
      )
      .where((snapshot) => snapshot == null || snapshot.key == key)
      .map((snapshot) => snapshot?.value);

  @override
  Future<void> writeEntries(Map<String, T> entries) => storeRef
      .records(entries.keys)
      .put(databaseClient, entries.values.toList(growable: false));

  @override
  Future<void> writeEntry(String key, T value) =>
      storeRef.record(key).put(databaseClient, value);
}
