import 'dart:async';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';

import '../core/store/store.dart';
import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';
import '../core/store/sync_object_store.dart';
import '../core/store/update_action.dart';
import 'lazy_hive_store.dart';

@internal
abstract class HiveSyncObjectStoreBase<T extends Object>
    implements SyncObjectStore<T> {
  @protected
  BoxBase<SyncObject<T>> get box;

  @override
  int count() => box.length;

  @override
  Iterable<String> listKeys() => box.keys.cast();

  @override
  bool contains(String key) => box.containsKey(key);

  @override
  Stream<StoreEvent<SyncObject<T>>> watch() =>
      box.watch().map((event) => StoreEvent(
            key: event.key as String,
            value: event.deleted ? null : (event.value as SyncObject<T>),
          ));
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
  void put(String key, SyncObject<T> value) {
    box.put(key, value);
  }

  @override
  UpdateResult<SyncObject<T>> update(
    String key,
    UpdateFn<SyncObject<T>> onUpdate,
  ) {
    final entry = box.get(key);
    return onUpdate(entry).when(
      none: () => UpdateResult(value: entry, updated: false),
      update: (value) {
        box.put(key, value);
        return UpdateResult(value: value, updated: true);
      },
      delete: () {
        box.delete(key);
        return const UpdateResult(value: null, updated: true);
      },
    );
  }

  @override
  void delete(String key) {
    box.delete(key);
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
          await Stream.fromIterable(box.keys)
              .asyncMap(
                (key) async => MapEntry(
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
  FutureOr<void> put(String key, SyncObject<T> value) => box.put(key, value);

  @override
  FutureOr<UpdateResult<SyncObject<T>>> update(
    String key,
    UpdateFn<SyncObject<T>> onUpdate,
  ) =>
      box.lock.synchronized(() async {
        final entry = await box.get(key);
        return onUpdate(entry).when(
          none: () => UpdateResult(value: entry, updated: false),
          update: (value) async {
            await box.put(key, value);
            return UpdateResult(value: value, updated: true);
          },
          delete: () async {
            await box.delete(key);
            return const UpdateResult(value: null, updated: true);
          },
        );
      });

  @override
  FutureOr<void> delete(String key) => box.delete(key);
}