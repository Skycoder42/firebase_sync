import '../local_store_event.dart';

abstract class LocalReadStore<T extends Object> {
  const LocalReadStore._();

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
