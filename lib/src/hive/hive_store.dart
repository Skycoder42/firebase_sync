import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import '../core/crypto/key_hasher.dart';
import '../core/store/store.dart';
import '../core/store/store_base.dart';
import '../core/store/store_event.dart';
import '../core/store/sync_object.dart';

class HiveStore<T extends Object> implements Store<T> {
  final Box<SyncObject<T>> _rawBox;
  final StoreBoundKeyHasher? _keyHasher;

  HiveStore(this._rawBox, [this._keyHasher]);

  @override
  int count() => _allEntries().length;

  @override
  Iterable<String> listKeys() =>
      _allEntries().map((entry) => _selectKey(entry));

  @override
  Map<String, T> listEntries() => Map.fromEntries(
        _allEntries().map(
          (entry) => MapEntry(
            _selectKey(entry),
            entry.value.value!,
          ),
        ),
      );

  @override
  bool contains(String key) => _rawBox.get(_realKey(key))?.value != null;

  @override
  T? get(String key) => _rawBox.get(_realKey(key))?.value;

  @override
  void put(String key, T value) {
    final realKey = _realKey(key);
    final entry = _rawBox.get(realKey);
    if (entry == null) {
      _rawBox.put(
        realKey,
        SyncObject.local(
          value,
          plainKey: _plainKey(key),
        ),
      );
    } else if (entry.value != value) {
      _rawBox.put(realKey, entry.updateLocal(value));
    }
  }

  @override
  T? update(String key, UpdateFn<T> onUpdate) {
    final realKey = _realKey(key);
    final entry = _rawBox.get(realKey);
    return onUpdate(entry?.value).when(
      none: () => entry?.value,
      update: (value) {
        if (entry == null) {
          _rawBox.put(
            realKey,
            SyncObject.local(
              value,
              plainKey: _plainKey(key),
            ),
          );
        } else {
          _rawBox.put(realKey, entry.updateLocal(value));
        }
        return value;
      },
      delete: () {
        if (entry != null) {
          _rawBox.put(realKey, entry.updateLocal(null));
        }
        return null;
      },
    );
  }

  @override
  void delete(String key) {
    final realKey = _realKey(key);
    final entry = _rawBox.get(realKey);
    if (entry?.value != null) {
      _rawBox.put(realKey, entry!.updateLocal(null));
    }
  }

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
          .valuesBetween(
            startKey: startKey != null ? _realKey(startKey) : null,
            endKey: endKey != null ? _realKey(endKey) : null,
          )
          .where((value) => value.value != null)
          .map((value) => value.value!);

  @protected
  Future<void> destroyBox() => _rawBox.deleteFromDisk();

  @protected
  Future<void> closeBox() => _rawBox.close();

  bool get _hashKeys => _keyHasher != null;

  String _realKey(String key) => _hashKeys ? _keyHasher!.hashKey(key) : key;

  String? _plainKey(String key) => _hashKeys ? key : null;

  String _selectKey(MapEntry<dynamic, SyncObject<T>> entry) =>
      _hashKeys ? entry.value.plainKey! : entry.key as String;

  Iterable<MapEntry<String, SyncObject<T>>> _allEntries() => _rawBox
      .toMap()
      .entries
      .where((entry) => entry.value.value != null)
      .cast();
}
