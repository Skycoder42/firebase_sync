import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/offline_store.dart';
import '../core/store/store.dart';
import '../core/store/store_event.dart';
import 'box_extensions.dart';
import 'hive_store.dart';

typedef CloseFn = void Function();

class HiveOfflineStore<T extends Object>
    implements HiveStore<T>, OfflineStore<T> {
  final Box<T> rawBox;
  final Uuid uuid;
  final CloseFn onClosed;

  HiveOfflineStore({
    required this.rawBox,
    required this.uuid,
    required this.onClosed,
  });

  @override
  int count() => rawBox.length;

  @override
  Iterable<String> listKeys() => rawBox.keys.cast();

  @override
  Map<String, T> listEntries() => rawBox.toMap().cast();

  @override
  bool contains(String key) => rawBox.containsKey(key);

  @override
  T? get(String key) => rawBox.get(key);

  @override
  String create(T value) {
    final key = rawBox.generateKey(uuid);
    rawBox.put(key, value);
    return key;
  }

  @override
  void put(String key, T value) => rawBox.put(key, value);

  @override
  T? update(String key, UpdateFn<T> onUpdate) {
    final value = rawBox.get(key);
    return onUpdate(value).when(
      none: () => value,
      update: (value) {
        rawBox.put(key, value);
        return value;
      },
      delete: () {
        rawBox.delete(key);
        return null;
      },
    );
  }

  @override
  void delete(String key) => rawBox.delete(key);

  @override
  Stream<StoreEvent<T>> watch() => rawBox.watch().map(
        (event) => StoreEvent(
          key: event.key as String,
          value: event.value as T?,
        ),
      );

  @override
  void clear() => rawBox.clear();

  @override
  bool get isEmpty => rawBox.isEmpty;

  @override
  bool get isNotEmpty => rawBox.isNotEmpty;

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
  Iterable<T> get values => rawBox.values;

  @override
  Iterable<T> valuesBetween({
    String? startKey,
    String? endKey,
  }) =>
      rawBox.valuesBetween(startKey: startKey, endKey: endKey);

  @override
  Future<void> close() async {
    onClosed();
    await rawBox.close();
  }

  @override
  Future<void> destroy() => rawBox.deleteFromDisk();
}
