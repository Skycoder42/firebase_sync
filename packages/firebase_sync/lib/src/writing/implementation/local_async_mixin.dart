import 'package:meta/meta.dart';

import '../../reading/implementation/local_async_mixing.dart';
import '../../storage/local_store_event.dart';
import '../../storage/storage.dart';
import '../../storage/write_storage_entry.dart';
import '../../utils/future_or_x.dart';
import '../write_store_local_async.dart';

export '../../reading/implementation/local_async_mixing.dart'
    show LocalAsyncMixinBase;

@internal
mixin LocalAsyncMixin<T extends Object> on LocalAsyncMixinBase<T>
    implements WriteStoreLocalAsync<T> {
  @override
  @visibleForOverriding
  Storage<WriteStorageEntry<T>> get storage;

  @override
  Future<Map<String, T>> asMap() => storage
      .entries()
      .then(
        (entries) => Map.fromEntries(
          entries.entries
              .where((entry) => entry.value.value != null)
              .map((e) => MapEntry(e.key, e.value.value!)),
        ),
      )
      .toFuture();

  @override
  Future<T?> value(String key) =>
      storage.readEntry(key).then((value) => value?.value).toFuture();

  @override
  Stream<LocalStoreEvent<T>> watch() => storage.watch().map(
        (event) => event.when<LocalStoreEvent<T>>(
          update: (key, value) => value.value != null
              ? LocalStoreEvent.update(key, value.value!)
              : LocalStoreEvent.delete(key),
          delete: (key) => LocalStoreEvent.delete(key),
        ),
      );

  @override
  Stream<T?> watchEntry(String key) =>
      storage.watchEntry(key).map((entry) => entry?.value);

  @override
  Future<void> setValue(String key, T value) => storage
      .transaction(
        (storage) => storage.readEntry(key).then(
              (entry) => storage.writeEntry(
                key,
                entry?.updateLocal(value) ?? WriteStorageEntry.local(value),
              ),
            ),
      )
      .toFuture();

  @override
  Future<void> setValues(Map<String, T> entries) =>
      storage.transaction((storage) async {
        final newEntries = <String, WriteStorageEntry<T>>{};
        for (final entry in entries.entries) {
          final oldEntry = await storage.readEntry(entry.key);
          newEntries[entry.key] = oldEntry?.updateLocal(entry.value) ??
              WriteStorageEntry.local(entry.value);
        }
        return storage.writeEntries(newEntries);
      }).toFuture();

  @override
  Future<void> deleteValue(String key) => storage
      .transaction(
        (storage) => storage.readEntry(key).then(
          (entry) {
            if (entry != null) {
              return storage.writeEntry(
                key,
                entry.updateLocal(null),
              );
            }
          },
        ),
      )
      .toFuture();

  @override
  Future<void> deleteValues(Iterable<String> keys) =>
      storage.transaction((storage) async {
        final deleteEntries = <String, WriteStorageEntry<T>>{};
        for (final key in keys) {
          final oldEntry = await storage.readEntry(key);
          if (oldEntry != null) {
            deleteEntries[key] = oldEntry.updateLocal(null);
          }
        }
        return storage.writeEntries(deleteEntries);
      }).toFuture();
}
