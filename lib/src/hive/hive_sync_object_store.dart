import 'dart:async';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';

import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';
import '../core/store/sync_object_store.dart';
import 'lazy_hive_store.dart';

@internal
abstract class HiveSyncObjectStoreBase<T extends Object>
    implements SyncObjectStore<T> {
  @protected
  BoxBase<SyncObject<T>> get box;

  @override
  Iterable<String> get rawKeys => box.keys.cast();

  @override
  Stream<StoreEvent<SyncObject<T>>> watch() => box.watch().map(
        (event) => StoreEvent(
          key: event.key as String,
          value: event.deleted ? null : (event.value as SyncObject<T>),
        ),
      );
}

@internal
class HiveSyncObjectStore<T extends Object> extends HiveSyncObjectStoreBase<T> {
  @override
  final Box<SyncObject<T>> box;

  HiveSyncObjectStore(this.box);

  @override
  Map<String, SyncObject<T>> listEntries() => box.toMap().cast();

  @override
  SyncObject<T>? get(String key) => box.get(key);

  @override
  SyncObject<T>? update(
    String key,
    UpdateFn<T> onUpdate,
  ) {
    final entry = box.get(key);
    return onUpdate(entry).when(
      none: () => entry,
      update: (value) {
        box.put(key, value);
        return value;
      },
      delete: () {
        box.delete(key);
        return null;
      },
    );
  }
}

@internal
class LazyHiveSyncObjectStore<T extends Object>
    extends HiveSyncObjectStoreBase<T> {
  @override
  final LazyBox<SyncObject<T>> box;

  LazyHiveSyncObjectStore(this.box);

  @override
  Future<Map<String, SyncObject<T>>> listEntries() => box.lock.synchronized(
        () async => Map.fromEntries(
          await Stream<dynamic>.fromIterable(box.keys)
              .asyncMap(
                (dynamic key) async => MapEntry(
                  key as String,
                  await box.get(key),
                ),
              )
              .where((entry) => entry.value != null)
              .cast<MapEntry<String, SyncObject<T>>>()
              .toList(),
        ),
      );

  @override
  Future<SyncObject<T>?> get(String key) => box.lock.synchronized(
        () => box.get(key),
      );

  @override
  FutureOr<SyncObject<T>?> update(
    String key,
    UpdateFn<T> onUpdate,
  ) =>
      box.lock.synchronized(() async {
        final entry = await box.get(key);
        return onUpdate(entry).when(
          none: () => entry,
          update: (value) async {
            await box.put(key, value);
            return value;
          },
          delete: () async {
            await box.delete(key);
            return null;
          },
        );
      });
}
