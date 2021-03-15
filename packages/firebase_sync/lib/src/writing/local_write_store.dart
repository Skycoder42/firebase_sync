import '../reading/local_read_store.dart';

abstract class LocalWriteStore<T extends Object> implements LocalReadStore<T> {
  Future<void> setValue(String key, T value);

  Future<void> deleteValue(String key);

  Future<void> localTransaction(); // TODO
}
