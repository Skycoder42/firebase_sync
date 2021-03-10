import 'read_only_store.dart';
import 'utils/future_or_x.dart';

class ReadOnlyStoreSyncReader<T> {
  final ReadOnlyStore<T> store;

  ReadOnlyStoreSyncReader(this.store)
      : assert(
          store.storage.isSync,
          'Cannot use ReadOnlyStoreSyncReader with asynchronous storages',
        );

  int get length => store.storage.length().sync;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => length != 0;

  List<String> get keys => store.storage.keys().sync;

  Map<String, T> asMap() => store.storage.entries().sync;

  bool contains(String key) => store.storage.contains(key).sync;

  T? value(String key) => store.storage.readEntry(key).sync;

  T? operator [](String key) => store.storage.readEntry(key).sync;

  Stream<dynamic> watch() => store.storage.watch().sync;

  Stream<dynamic> watchEntry(String key) => store.storage.watchEntry(key).sync;
}
