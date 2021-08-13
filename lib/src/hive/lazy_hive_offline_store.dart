import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/offline_store.dart';
import '../core/store/store.dart';
import '../core/store/store_event.dart';
import 'box_extensions.dart';
import 'lazy_hive_store.dart';

class LazyHiveOfflineStore<T extends Object>
    implements LazyHiveStore<T>, OfflineStore<T> {
  final LazyBox<T> _rawBox;
  final Uuid _uuid;

  LazyHiveOfflineStore(this._rawBox, this._uuid);

  @override
  Future<int> count() => Future.value(_rawBox.length);

  @override
  Future<Iterable<String>> listKeys() => Future.value(_rawBox.keys.cast());

  @override
  Future<Map<String, T>> listEntries() => _run(
        () async => Map.fromEntries(
          await Stream.fromIterable(_rawBox.keys.cast<String>())
              .asyncMap((key) async => MapEntry(key, await _rawBox.get(key)))
              .where((entry) => entry.value != null)
              .cast<MapEntry<String, T>>()
              .toList(),
        ),
      );

  @override
  Future<bool> contains(String key) => Future.value(_rawBox.containsKey(key));

  @override
  Future<T?> get(String key) => _run(() => _rawBox.get(key));

  @override
  Future<String> create(T value) => _run(() async {
        final key = _rawBox.generateKey(_uuid);
        await _rawBox.put(key, value);
        return key;
      });

  @override
  Future<void> put(String key, T value) => _run(() => _rawBox.put(key, value));

  @override
  Future<T?> update(String key, UpdateFn<T> onUpdate) => _run(() async {
        final value = await _rawBox.get(key);
        return onUpdate(value).when(
          none: () => value,
          update: (value) async {
            await _rawBox.put(key, value);
            return value;
          },
          delete: () async {
            await _rawBox.delete(key);
            return null;
          },
        );
      });

  @override
  Future<void> delete(String key) => _run(() => _rawBox.delete(key));

  @override
  Stream<StoreEvent<T>> watch() => _rawBox.watch().map(
        (entry) => StoreEvent(
          key: entry.key as String,
          value: entry.value as T?,
        ),
      );

  @override
  Future<void> clear() => _run(() => _rawBox.clear());

  @override
  Future<bool> get isEmpty => Future.value(_rawBox.isEmpty);

  @override
  Future<bool> get isNotEmpty => Future.value(_rawBox.isNotEmpty);

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
        () => Stream.fromIterable(_rawBox.keys.cast<String>())
            .asyncMap((key) => _rawBox.get(key))
            .where((value) => value != null)
            .cast<T>()
            .toList(),
      );

  @override
  Future<void> close() => _rawBox.close();

  @override
  Future<void> destroy() => _rawBox.deleteFromDisk();

  Future<TR> _run<TR>(FutureOr<TR> Function() run) =>
      _rawBox.lock.synchronized(run);
}
