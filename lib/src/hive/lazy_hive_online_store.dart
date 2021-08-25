import 'dart:async';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../core/store/store.dart';
import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';
import 'box_extensions.dart';
import 'lazy_hive_store.dart';

class LazyHiveOnlineStore<T extends Object> implements LazyHiveStore<T> {
  final LazyBox<SyncObject<T>> _rawBox;
  final Uuid _uuid;

  LazyHiveOnlineStore(this._rawBox, this._uuid);

  @override
  Future<int> count() => _run(
        () => _allEntries().length,
      );

  @override
  Future<Iterable<String>> listKeys() => _run(
        () => _allEntries().map((entry) => entry.key).toList(),
      );

  @override
  Future<Map<String, T>> listEntries() => _run(
        () async => Map.fromEntries(
          await _allEntries()
              .map(
                (entry) => MapEntry(
                  entry.key,
                  entry.value.value!,
                ),
              )
              .toList(),
        ),
      );

  @override
  Future<bool> contains(String key) => _run(
        () => _rawBox.get(key).then((value) => value?.value != null),
      );

  @override
  Future<T?> get(String key) => _run(
        () => _rawBox.get(key).then((value) => value?.value),
      );

  @override
  Future<String> create(T value) => _run(() async {
        final key = _rawBox.generateKey(_uuid);
        await _rawBox.put(
          key,
          SyncObject.local(value),
        );
        return key;
      });

  @override
  Future<void> put(String key, T value) => _run(() async {
        final entry = await _rawBox.get(key);
        if (entry == null) {
          await _rawBox.put(
            key,
            SyncObject.local(value),
          );
        } else if (entry.value != value) {
          await _rawBox.put(key, entry.updateLocal(value));
        }
      });

  @override
  Future<T?> update(String key, UpdateFn<T> onUpdate) => _run(() async {
        final entry = await _rawBox.get(key);
        return onUpdate(entry?.value).when(
          none: () => entry?.value,
          update: (value) async {
            if (entry == null) {
              await _rawBox.put(
                key,
                SyncObject.local(value),
              );
            } else {
              await _rawBox.put(key, entry.updateLocal(value));
            }
            return value;
          },
          delete: () async {
            if (entry != null) {
              await _rawBox.put(key, entry.updateLocal(null));
            }
            return null;
          },
        );
      });

  @override
  Future<void> delete(String key) => _run(() async {
        final entry = await _rawBox.get(key);
        if (entry?.value != null) {
          await _rawBox.put(key, entry!.updateLocal(null));
        }
      });

  @override
  Stream<StoreEvent<T>> watch() =>
      _rawBox.watch().where((event) => !event.deleted).map(
            (event) => StoreEvent(
              key: event.key as String,
              value: (event.value as SyncObject<T>).value,
            ),
          );

  @override
  Future<void> clear() => _run(() => _rawBox.clear());

  @override
  Future<bool> get isEmpty => count().then((v) => v == 0);

  @override
  Future<bool> get isNotEmpty => count().then((v) => v > 0);

  @override
  bool get isOpen => _rawBox.isOpen;

  @override
  bool get lazy => _rawBox.lazy;

  @override
  String get name => _rawBox.name;

  @override
  String? get path => _rawBox.path;

  @override
  Future<void> compact() => _rawBox.compact();

  @override
  Future<Iterable<T>> values() => _run(
        () => _allEntries().map((entry) => entry.value.value!).toList(),
      );

  @override
  @mustCallSuper
  Future<void> destroy() => _rawBox.deleteFromDisk();

  @override
  @mustCallSuper
  Future<void> close() => _rawBox.close();

  Future<TR> _run<TR>(FutureOr<TR> Function() run) =>
      _rawBox.lock.synchronized(run);

  Stream<MapEntry<String, SyncObject<T>>> _allEntries() =>
      Stream<dynamic>.fromIterable(_rawBox.keys)
          .asyncMap(
            (dynamic key) async => MapEntry(
              key as String,
              await _rawBox.get(key),
            ),
          )
          .where((entry) => entry.value?.value != null)
          .cast<MapEntry<String, SyncObject<T>>>();
}
