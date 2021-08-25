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
  final LazyBox<T> rawBox;
  final Uuid uuid;
  final void Function() onClosed;

  LazyHiveOfflineStore({
    required this.rawBox,
    required this.uuid,
    required this.onClosed,
  });

  @override
  Future<int> count() => Future.value(rawBox.length);

  @override
  Future<Iterable<String>> listKeys() => Future.value(rawBox.keys.cast());

  @override
  Future<Map<String, T>> listEntries() => _run(
        () async => Map.fromEntries(
          await Stream.fromIterable(rawBox.keys.cast<String>())
              .asyncMap((key) async => MapEntry(key, await rawBox.get(key)))
              .where((entry) => entry.value != null)
              .cast<MapEntry<String, T>>()
              .toList(),
        ),
      );

  @override
  Future<bool> contains(String key) => Future.value(rawBox.containsKey(key));

  @override
  Future<T?> get(String key) => _run(() => rawBox.get(key));

  @override
  Future<String> create(T value) => _run(() async {
        final key = rawBox.generateKey(uuid);
        await rawBox.put(key, value);
        return key;
      });

  @override
  Future<void> put(String key, T value) => _run(() => rawBox.put(key, value));

  @override
  Future<T?> update(String key, UpdateFn<T> onUpdate) => _run(() async {
        final value = await rawBox.get(key);
        return onUpdate(value).when(
          none: () => value,
          update: (value) async {
            await rawBox.put(key, value);
            return value;
          },
          delete: () async {
            await rawBox.delete(key);
            return null;
          },
        );
      });

  @override
  Future<void> delete(String key) => _run(() => rawBox.delete(key));

  @override
  Stream<StoreEvent<T>> watch() => rawBox.watch().map(
        (entry) => StoreEvent(
          key: entry.key as String,
          value: entry.value as T?,
        ),
      );

  @override
  Future<void> clear() => _run(() => rawBox.clear());

  @override
  Future<bool> get isEmpty => Future.value(rawBox.isEmpty);

  @override
  Future<bool> get isNotEmpty => Future.value(rawBox.isNotEmpty);

  @override
  bool get isOpen => rawBox.isOpen;

  @override
  bool get lazy => rawBox.lazy;

  @override
  String get name => rawBox.name;

  @override
  String? get path => rawBox.path;

  @override
  Future<void> compact() => rawBox.compact();

  @override
  Future<Iterable<T>> values() => _run(
        () => Stream.fromIterable(rawBox.keys.cast<String>())
            .asyncMap((key) => rawBox.get(key))
            .where((value) => value != null)
            .cast<T>()
            .toList(),
      );

  @override
  Future<void> close() => rawBox.close();

  @override
  Future<void> destroy() => rawBox.deleteFromDisk();

  Future<TR> _run<TR>(FutureOr<TR> Function() run) =>
      rawBox.lock.synchronized(run);
}
