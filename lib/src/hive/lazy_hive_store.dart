import 'dart:async';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import '../core/crypto/key_hasher.dart';
import '../core/store/store.dart';
import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';

class LazyHiveStore<T extends Object> implements Store<T> {
  final LazyBox<SyncObject<T>> _rawBox;
  final StoreBoundKeyHasher? _keyHasher;

  LazyHiveStore(this._rawBox, this._keyHasher);

  @override
  Future<int> count() => _run(
        () => _allEntries().length,
      );

  @override
  Future<Iterable<String>> listKeys() => _run(
        () => _allEntries().map((entry) => _selectKey(entry)).toList(),
      );

  @override
  Future<Map<String, T>> listEntries() => _run(
        () async => Map.fromEntries(
          await _allEntries()
              .map(
                (entry) => MapEntry(
                  _selectKey(entry),
                  entry.value.value!,
                ),
              )
              .toList(),
        ),
      );

  @override
  Future<bool> contains(String key) => _run(
        () => _rawBox.get(_realKey(key)).then((value) => value?.value != null),
      );

  @override
  Future<T?> get(String key) => _run(
        () => _rawBox.get(_realKey(key)).then((value) => value?.value),
      );

  @override
  Future<void> put(String key, T value) => _run(() async {
        final realKey = _realKey(key);
        final entry = await _rawBox.get(realKey);
        if (entry == null) {
          await _rawBox.put(
            realKey,
            SyncObject.local(
              value,
              plainKey: _plainKey(key),
            ),
          );
        } else if (entry.value != value) {
          await _rawBox.put(realKey, entry.updateLocal(value));
        }
      });

  @override
  Future<T?> update(String key, UpdateFn<T> onUpdate) => _run(() async {
        final realKey = _realKey(key);
        final entry = await _rawBox.get(realKey);
        return onUpdate(entry?.value).when(
          none: () => entry?.value,
          update: (value) async {
            if (entry == null) {
              await _rawBox.put(
                realKey,
                SyncObject.local(
                  value,
                  plainKey: _plainKey(key),
                ),
              );
            } else {
              await _rawBox.put(realKey, entry.updateLocal(value));
            }
            return value;
          },
          delete: () async {
            if (entry != null) {
              await _rawBox.put(realKey, entry.updateLocal(null));
            }
            return null;
          },
        );
      });

  @override
  Future<void> delete(String key) => _run(() async {
        final realKey = _realKey(key);
        final entry = await _rawBox.get(realKey);
        if (entry?.value != null) {
          await _rawBox.put(realKey, entry!.updateLocal(null));
        }
      });

  @override
  Stream<StoreEvent<T>> watch() => _rawBox
      .watch()
      .where((event) => !event.deleted)
      .map(
        (event) => MapEntry(
          event.key as String,
          event.value as SyncObject<T>,
        ),
      )
      .map(
        (entry) => StoreEvent(
          key: _selectKey(entry),
          value: entry.value.value,
        ),
      );

  @override
  Future<void> clear() async {
    await _rawBox.clear();
  }

  // hive extensions

  Future<bool> isEmpty() => count().then((v) => v == 0);

  Future<bool> isNotEmpty() => count().then((v) => v > 0);

  bool get isOpen => _rawBox.isOpen;

  bool get lazy => _rawBox.lazy;

  String get name => _rawBox.name;

  String? get path => _rawBox.path;

  Future<void> compact() => _rawBox.compact();

  Future<Iterable<T>> values() => _run(
        () => _allEntries().map((entry) => entry.value.value!).toList(),
      );

  @protected
  Future<void> destroyBox() => _rawBox.deleteFromDisk();

  @protected
  Future<void> closeBox() => _rawBox.close();

  Future<TR> _run<TR>(FutureOr<TR> Function() run) =>
      _rawBox.lock.synchronized(run);

  bool get _hashKeys => _keyHasher != null;

  String _realKey(String key) => _hashKeys ? _keyHasher!.hashKey(key) : key;

  String? _plainKey(String key) => _hashKeys ? key : null;

  String _selectKey(MapEntry<String, SyncObject<T>> entry) =>
      _hashKeys ? entry.value.plainKey! : entry.key;

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

@internal
extension LazyBoxLocksX on LazyBox<dynamic> {
  static late final _boxLocks = Expando<Lock>();

  Lock get lock => _boxLocks[this] ??= Lock();
}
