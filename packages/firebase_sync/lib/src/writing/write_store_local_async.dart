import 'dart:async';

import '../../firebase_sync.dart';
import '../reading/read_store_local_async.dart';

typedef AsyncTransactionFn<T extends Object, TR> = FutureOr<TR> Function(
  WriteStoreLocalAsync<T> transaction,
);

abstract class WriteStoreLocalAsync<T extends Object>
    implements ReadStoreLocalAsync<T> {
  const WriteStoreLocalAsync._();

  Future<void> setValue(String key, T value);

  Future<void> setValues(Map<String, T> entries);

  Future<void> deleteValue(String key);

  Future<void> deleteValues(Iterable<String> keys);

  Future<TR> transaction<TR>(AsyncTransactionFn<T, TR> transaction);
}
