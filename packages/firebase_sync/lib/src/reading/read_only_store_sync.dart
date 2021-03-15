import '../local_store_event.dart';
import '../storage/storage.dart';
import '../utils/future_or_x.dart';
import 'local_read_store_sync.dart';

class ReadOnlyStoreSync<T extends Object> implements LocalReadStoreSync<T> {
  final Storage<T> storage;

  ReadOnlyStoreSync(this.storage)
      : assert(
          storage.isSync,
          'Cannot use ReadOnlyStoreSyncReader with asynchronous storages',
        );

  @override
  int get length => storage.length().sync;

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length != 0;

  @override
  List<String> get keys => storage.keys().sync;

  @override
  Map<String, T> asMap() => storage.entries().sync;

  @override
  bool contains(String key) => storage.contains(key).sync;

  @override
  T? value(String key) => storage.readEntry(key).sync;

  @override
  Stream<LocalStoreEvent<T>> watch() => storage.watch().sync;

  @override
  Stream<T?> watchEntry(String key) => storage.watchEntry(key).sync;

  @override
  T? operator [](String key) => storage.readEntry(key).sync;
}
