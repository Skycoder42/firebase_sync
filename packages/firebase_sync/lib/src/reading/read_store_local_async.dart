import '../storage/local_store_event.dart';

abstract class ReadStoreLocalAsync<T extends Object> {
  const ReadStoreLocalAsync._(); // coverage:ignore-line

  Future<int> length();

  Future<bool> isEmpty();

  Future<bool> isNotEmpty();

  Future<Iterable<String>> keys();

  Future<Map<String, T>> asMap();

  Future<bool> contains(String key);

  Future<T?> value(String key);

  Stream<LocalStoreEvent<T>> watch();

  Stream<T?> watchEntry(String key);

  Future<void> clear();
}
