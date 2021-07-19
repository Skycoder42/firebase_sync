import 'dart:async';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import '../core/store/store.dart';
import '../core/store/store_base.dart';
import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';

class LazyHiveStore<T extends Object> implements Store<T> {
  final LazyBox<SyncObject<T>> _rawBox;

  LazyHiveStore(this._rawBox);

  @override
  Future<int> count() => _run(
        () => Stream<dynamic>.fromIterable(_rawBox.keys)
            .asyncMap((dynamic key) => _rawBox.get(key))
            .where((value) => value?.value != null)
            .length,
      );

  @override
  Future<Iterable<String>> listKeys() => _run(
        () => Stream<dynamic>.fromIterable(_rawBox.keys)
            .asyncMap(
              (dynamic key) async => MapEntry<dynamic, SyncObject<T>?>(
                key,
                await _rawBox.get(key),
              ),
            )
            .where((entry) => entry.value?.value != null)
            .map((entry) => entry.key as String)
            .toList(),
      );

  @override
  Future<Map<String, T>> listEntries() => _run(
        () async => Map.fromEntries(
          await Stream<dynamic>.fromIterable(_rawBox.keys)
              .asyncMap(
                (dynamic key) async => MapEntry(
                  key as String,
                  await _rawBox.get(key),
                ),
              )
              .where((entry) => entry.value?.value != null)
              .map((entry) => MapEntry(entry.key, entry.value!.value!))
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
  Future<void> put(String key, T value) => _run(() async {
        final entry = await _rawBox.get(key);
        if (entry == null) {
          await _rawBox.put(key, SyncObject.local(value));
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
              await _rawBox.put(key, SyncObject.local(value));
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
  Stream<StoreEvent<T>> watch() => _rawBox.watch().map(
        (event) => StoreEvent(
          key: event.key as String,
          value: event.deleted ? null : (event as SyncObject<T>).value,
        ),
      );

  // hive extensions

  Future<bool> isEmpty() => count().then((v) => v == 0);

  Future<bool> isNotEmpty() => count().then((v) => v > 0);

  bool get isOpen => _rawBox.isOpen;

  bool get lazy => _rawBox.lazy;

  String get name => _rawBox.name;

  String? get path => _rawBox.path;

  // TODO clear

  @protected
  Future<void> closeBox() => _rawBox.close();

  Future<void> compact() => _rawBox.compact();

  // TODO stop sync if running?
  Future<void> deleteFromDisk() => _rawBox.deleteFromDisk();

  Future<Iterable<T>> values() => _run(
        () => Stream<dynamic>.fromIterable(_rawBox.keys)
            .asyncMap((dynamic key) => _rawBox.get(key))
            .where((value) => value?.value != null)
            .map((value) => value!.value!)
            .toList(),
      );

  Future<TR> _run<TR>(FutureOr<TR> Function() run) =>
      _rawBox.lock.synchronized(run);
}

@internal
extension LazyBoxLocksX on LazyBox<dynamic> {
  static late final _boxLocks = Expando<Lock>();

  Lock get lock => _boxLocks[this] ??= Lock();
}
