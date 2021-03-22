import 'package:meta/meta.dart';

import '../../storage/local_store_event.dart';
import '../../storage/storage.dart';
import '../../utils/future_or_x.dart';
import '../read_store_local_async.dart';

@internal
mixin LocalAsyncMixinBase<T extends Object> implements ReadStoreLocalAsync<T> {
  @visibleForOverriding
  Storage<dynamic> get storage;

  @override
  Future<int> length() => storage.length().toFuture();

  @override
  Future<bool> isEmpty() {
    final length = storage.length();
    if (length is Future<int>) {
      return length.then((value) => value == 0);
    } else {
      return Future.value(length == 0);
    }
  }

  @override
  Future<bool> isNotEmpty() {
    final length = storage.length();
    if (length is Future<int>) {
      return length.then((value) => value != 0);
    } else {
      return Future.value(length != 0);
    }
  }

  @override
  Future<Iterable<String>> keys() => storage.keys().toFuture();

  @override
  Future<bool> contains(String key) => storage.contains(key).toFuture();

  @override
  Future<void> clear() => storage.clear().toFuture();
}

@internal
mixin LocalAsyncMixin<T extends Object> on LocalAsyncMixinBase<T> {
  @override
  @visibleForOverriding
  Storage<T> get storage;

  @override
  Future<Map<String, T>> asMap() => storage.entries().toFuture();

  @override
  Future<T?> value(String key) => storage.readEntry(key).toFuture();

  @override
  Future<Stream<LocalStoreEvent<T>>> watch() => storage.watch().toFuture();

  @override
  Future<Stream<T?>> watchEntry(String key) =>
      storage.watchEntry(key).toFuture();
}
