import 'package:meta/meta.dart';

import '../../storage/local_store_event.dart';
import '../../storage/storage.dart';
import '../../utils/future_or_x.dart';
import '../read_store_local_sync.dart';

mixin LocalSyncMixinBase<T extends Object> implements ReadStoreLocalSync<T> {
  @visibleForOverriding
  Storage<dynamic> get storage;

  @override
  int get length => storage.length().sync;

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length != 0;

  @override
  Iterable<String> get keys => storage.keys().sync;

  @override
  bool contains(String key) => storage.contains(key).sync;

  @override
  void clear() => storage.clear().sync;
}

@internal
mixin LocalSyncMixin<T extends Object> on LocalSyncMixinBase<T> {
  @override
  @visibleForOverriding
  Storage<T> get storage;

  @override
  Map<String, T> asMap() => storage.entries().sync;

  @override
  T? value(String key) => storage.readEntry(key).sync;

  @override
  Stream<LocalStoreEvent<T>> watch() => storage.watch().sync;

  @override
  Stream<T?> watchEntry(String key) => storage.watchEntry(key).sync;

  @override
  T? operator [](String key) => storage.readEntry(key).sync;
}
