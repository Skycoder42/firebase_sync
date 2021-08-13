import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/offline_store.dart';
import '../core/store/store.dart';
import '../core/store/store_event.dart';
import 'box_extensions.dart';
import 'hive_store.dart';

class HiveOfflineStore<T extends Object>
    implements HiveStore<T>, OfflineStore<T> {
  final Box<T> _rawBox;
  final Uuid _uuid;

  HiveOfflineStore(this._rawBox, this._uuid);

  @override
  int count() => _rawBox.length;

  @override
  Iterable<String> listKeys() => _rawBox.keys.cast();

  @override
  Map<String, T> listEntries() => _rawBox.toMap().cast();

  @override
  bool contains(String key) => _rawBox.containsKey(key);

  @override
  T? get(String key) => _rawBox.get(key);

  @override
  String create(T value) {
    final key = _rawBox.generateKey(_uuid);
    _rawBox.put(key, value);
    return key;
  }

  @override
  void put(String key, T value) => _rawBox.put(key, value);

  @override
  T? update(String key, UpdateFn<T> onUpdate) {
    final value = _rawBox.get(key);
    return onUpdate(value).when(
      none: () => value,
      update: (value) {
        _rawBox.put(key, value);
        return value;
      },
      delete: () {
        _rawBox.delete(key);
        return null;
      },
    );
  }

  @override
  void delete(String key) => _rawBox.delete(key);

  @override
  Stream<StoreEvent<T>> watch() => _rawBox.watch().map(
        (event) => StoreEvent(
          key: event.key as String,
          value: event.value as T?,
        ),
      );

  @override
  void clear() => _rawBox.clear();

  @override
  bool get isEmpty => _rawBox.isEmpty;

  @override
  bool get isNotEmpty => _rawBox.isNotEmpty;

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
  Iterable<T> get values => _rawBox.values;

  @override
  Iterable<T> valuesBetween({
    String? startKey,
    String? endKey,
  }) =>
      _rawBox.valuesBetween(startKey: startKey, endKey: endKey);

  @override
  Future<void> close() => _rawBox.close();

  @override
  Future<void> destroy() => _rawBox.deleteFromDisk();
}
