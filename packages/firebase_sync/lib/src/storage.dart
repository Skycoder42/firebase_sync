import 'dart:async';

abstract class Storage<T> {
  const Storage._();

  bool get isSync;

  FutureOr<int> length();

  FutureOr<List<String>> keys();

  FutureOr<Map<String, T>> entries();

  FutureOr<bool> contains(String key);

  FutureOr<T?> readEntry(String key);

  FutureOr<Stream<dynamic>> watch();

  FutureOr<Stream<dynamic>> watchEntry(String key);

  Future<void> writeEntry(String key, T value);

  Future<void> deleteEntry(String key);

  Future<void> clear();
}

abstract class JsonStorage<T> implements Storage<dynamic> {}
