import 'dart:async';

import '../local_store_event.dart';

typedef TransactionFn<T extends Object, TR> = FutureOr<TR> Function(
  Storage<T> storage,
);

abstract class Storage<T extends Object> {
  const Storage._();

  bool get isSync;

  FutureOr<int> length();

  FutureOr<Iterable<String>> keys();

  FutureOr<Map<String, T>> entries();

  FutureOr<bool> contains(String key);

  FutureOr<T?> readEntry(String key);

  Stream<LocalStoreEvent<T>> watch();

  Stream<T?> watchEntry(String key);

  FutureOr<void> writeEntry(String key, T value);

  FutureOr<void> writeEntries(Map<String, T> entries);

  FutureOr<void> deleteEntry(String key);

  FutureOr<void> deleteEntries(Iterable<String> keys);

  FutureOr<void> clear();

  FutureOr<void> destroy();

  FutureOr<TR> transaction<TR>(TransactionFn<T, TR> transactionCallback);

  Future<void> close();
}
