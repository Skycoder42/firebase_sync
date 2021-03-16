import '../local_store_event.dart';

abstract class ReadStoreLocalAsync<T extends Object> {
  const ReadStoreLocalAsync._();

  Future<int> length();

  Future<bool> isEmpty();

  Future<bool> isNotEmpty();

  Future<List<String>> keys();

  Future<Map<String, T>> asMap();

  Future<bool> contains(String key);

  Future<T?> value(String key);

  Future<Stream<LocalStoreEvent<T>>> watch();

  Future<Stream<T?>> watchEntry(String key);

  Future<void> clear();
}
