import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/store/store.dart';
import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';

class HiveStore<T extends Object> implements Store<T> {
  final Box<SyncObject<T>> _rawBox;
  final Uuid _uuid;

  HiveStore(this._rawBox, this._uuid);

  @override
  int count() => _allEntries().length;

  @override
  Iterable<String> listKeys() => _allEntries().map((entry) => entry.key);

  @override
  Map<String, T> listEntries() => Map.fromEntries(
        _allEntries().map(
          (entry) => MapEntry(
            entry.key,
            entry.value.value!,
          ),
        ),
      );

  @override
  bool contains(String key) => _rawBox.get(key)?.value != null;

  @override
  T? get(String key) => _rawBox.get(key)?.value;

  @override
  String create(T value) {
    String key;
    do {
      key = _uuid.v4();
    } while (_rawBox.containsKey(key));

    _rawBox.put(
      key,
      SyncObject.local(value),
    );

    return key;
  }

  @override
  void put(String key, T value) {
    final entry = _rawBox.get(key);
    if (entry == null) {
      _rawBox.put(
        key,
        SyncObject.local(value),
      );
    } else if (entry.value != value) {
      _rawBox.put(key, entry.updateLocal(value));
    }
  }

  @override
  T? update(String key, UpdateFn<T> onUpdate) {
    final entry = _rawBox.get(key);
    return onUpdate(entry?.value).when(
      none: () => entry?.value,
      update: (value) {
        if (entry == null) {
          _rawBox.put(
            key,
            SyncObject.local(value),
          );
        } else {
          _rawBox.put(key, entry.updateLocal(value));
        }
        return value;
      },
      delete: () {
        if (entry != null) {
          _rawBox.put(key, entry.updateLocal(null));
        }
        return null;
      },
    );
  }

  @override
  void delete(String key) {
    final entry = _rawBox.get(key);
    if (entry?.value != null) {
      _rawBox.put(key, entry!.updateLocal(null));
    }
  }

  @override
  Stream<StoreEvent<T>> watch() =>
      _rawBox.watch().where((event) => !event.deleted).map(
            (event) => StoreEvent(
              key: event.key as String,
              value: (event.value as SyncObject<T>).value,
            ),
          );

  @override
  Future<void> clear() async {
    await _rawBox.clear();
  }

  // hive extensions

  bool get isEmpty => count() == 0;

  bool get isNotEmpty => count() > 0;

  bool get isOpen => _rawBox.isOpen;

  bool get lazy => _rawBox.lazy;

  String get name => _rawBox.name;

  String? get path => _rawBox.path;

  Future<void> compact() => _rawBox.compact();

  Iterable<T> get values => _rawBox.values
      .where((value) => value.value != null)
      .map((value) => value.value!);

  Iterable<T> valuesBetween({
    String? startKey,
    String? endKey,
  }) =>
      _rawBox
          .valuesBetween(startKey: startKey, endKey: endKey)
          .where((value) => value.value != null)
          .map((value) => value.value!);

  @protected
  Future<void> destroyBox() => _rawBox.deleteFromDisk();

  @protected
  Future<void> closeBox() => _rawBox.close();

  Iterable<MapEntry<String, SyncObject<T>>> _allEntries() => _rawBox
      .toMap()
      .entries
      .where((entry) => entry.value.value != null)
      .cast();
}
