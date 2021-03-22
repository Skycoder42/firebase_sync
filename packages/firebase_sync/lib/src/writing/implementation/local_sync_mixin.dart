import 'package:meta/meta.dart';

import '../../reading/implementation/local_sync_mixin.dart';
import '../../storage/local_store_event.dart';
import '../../storage/storage.dart';
import '../../storage/write_storage_entry.dart';
import '../../utils/future_or_x.dart';
import '../write_store_local_sync.dart';

export '../../reading/implementation/local_sync_mixin.dart'
    show LocalSyncMixinBase;

@internal
mixin LocalSyncMixin<T extends Object> on LocalSyncMixinBase<T>
    implements WriteStoreLocalSync<T> {
  @override
  @visibleForOverriding
  Storage<WriteStorageEntry<T>> get storage;

  @override
  Map<String, T> asMap() => Map.fromEntries(
        storage
            .entries()
            .sync
            .entries
            .where((entry) => entry.value.value != null)
            .map((e) => MapEntry(e.key, e.value.value!)),
      );

  @override
  T? value(String key) => storage.readEntry(key).sync?.value;

  @override
  Stream<LocalStoreEvent<T>> watch() => storage.watch().sync.map(
        (event) => event.when<LocalStoreEvent<T>>(
          update: (key, value) => value.value != null
              ? LocalStoreEvent.update(key, value.value!)
              : LocalStoreEvent.delete(key),
          delete: (key) => LocalStoreEvent.delete(key),
        ),
      );

  @override
  Stream<T?> watchEntry(String key) =>
      storage.watchEntry(key).sync.map((entry) => entry?.value);

  @override
  void setValue(String key, T value) => storage
      .transaction(
        (storage) => storage.writeEntry(
          key,
          storage.readEntry(key).sync?.updateLocal(value) ??
              WriteStorageEntry.local(value),
        ),
      )
      .sync;

  @override
  void setValues(Map<String, T> entries) => storage.transaction(
        (storage) {
          final newEntries = <String, WriteStorageEntry<T>>{};
          for (final entry in entries.entries) {
            final oldEntry = storage.readEntry(entry.key).sync;
            newEntries[entry.key] = oldEntry?.updateLocal(entry.value) ??
                WriteStorageEntry.local(entry.value);
          }
          return storage.writeEntries(newEntries);
        },
      ).sync;

  @override
  void deleteValue(String key) => storage.transaction(
        (storage) {
          final oldEntry = storage.readEntry(key).sync;
          if (oldEntry != null) {
            return storage.writeEntry(key, oldEntry.updateLocal(null));
          }
        },
      ).sync;

  @override
  void deleteValues(Iterable<String> keys) => storage.transaction(
        (storage) {
          final deleteEntries = <String, WriteStorageEntry<T>>{};
          for (final key in keys) {
            final oldEntry = storage.readEntry(key).sync;
            if (oldEntry != null) {
              deleteEntries[key] = oldEntry.updateLocal(null);
            }
          }
          return storage.writeEntries(deleteEntries);
        },
      ).sync;

  @override
  T? operator [](String key) => value(key);

  @override
  void operator []=(String key, T value) => setValue(key, value);
}
