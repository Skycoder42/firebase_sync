import '../reading/read_store_local_sync.dart';

typedef SyncTransactionFn<T extends Object, TR> = TR Function(
  WriteStoreLocalSync<T> transaction,
);

abstract class WriteStoreLocalSync<T extends Object>
    implements ReadStoreLocalSync<T> {
  const WriteStoreLocalSync._();

  void setValue(String key, T value);

  void setValues(Map<String, T> entries);

  void deleteValue(String key);

  void deleteValues(Iterable<String> keys);

  void operator []=(String key, T value);

  TR transaction<TR>(SyncTransactionFn<T, TR> transaction);
}
