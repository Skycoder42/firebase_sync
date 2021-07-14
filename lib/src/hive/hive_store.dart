import 'package:hive/hive.dart';
import 'package:meta/meta.dart';

import '../core/store.dart';
import '../core/store_event.dart';
import '../core/sync_object.dart';
import '../core/update_action.dart';
import '../sync/sync_mixin.dart';
import 'hive_sync_store.dart';

class HiveStore<T extends Object> with SyncMixin<T> implements Store<T> {
  final Box<SyncObject<T>> _rawBox;

  HiveStore(this._rawBox);

  @override
  @internal
  late final SyncStore<T> syncStore = HiveSyncStore(_rawBox);

  @override
  int count() => _rawBox
      .toMap()
      .entries
      .where((entry) => entry.value.value != null)
      .length;

  @override
  Iterable<String> listKeys() => _rawBox
      .toMap()
      .entries
      .where((entry) => entry.value.value != null)
      .map((entry) => entry.key as String);

  @override
  Map<String, T> listEntries() => Map.fromEntries(
        _rawBox
            .toMap()
            .entries
            .where((entry) => entry.value.value != null)
            .map((entry) => MapEntry(entry.key as String, entry.value.value!)),
      );

  @override
  bool contains(String key) => _rawBox.get(key)?.value != null;

  @override
  T? get(String key) => _rawBox.get(key)?.value;

  @override
  void put(String key, T value) {
    final entry = _rawBox.get(key);
    if (entry == null) {
      _rawBox.put(key, SyncObject.local(value));
    } else if (entry.value != value) {
      _rawBox.put(key, entry.updateLocal(value));
    }
  }

  @override
  UpdateResult<T> update(String key, UpdateFn<T> onUpdate) {
    final entry = _rawBox.get(key);
    return onUpdate(entry?.value).when(
      none: () => UpdateResult(value: entry?.value, updated: false),
      update: (value) {
        if (entry == null) {
          _rawBox.put(key, SyncObject.local(value));
        } else {
          _rawBox.put(key, entry.updateLocal(value));
        }
        return UpdateResult(value: value, updated: true);
      },
      delete: () {
        if (entry != null) {
          _rawBox.put(key, entry.updateLocal(null));
        }
        return const UpdateResult(value: null, updated: true);
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
  Stream<StoreEvent<T>> watch() => _rawBox.watch().map(
        (event) => StoreEvent(
          key: event.key as String,
          value: event.deleted ? null : (event as SyncObject<T>).value,
        ),
      );

  // hive extensions

  bool get isEmpty => count() == 0;

  bool get isNotEmpty => count() > 0;

  bool get isOpen => _rawBox.isOpen;

  bool get lazy => _rawBox.lazy;

  String get name => _rawBox.name;

  String? get path => _rawBox.path;

  // TODO clear

  Future<void> close() => _rawBox.close();

  Future<void> compact() => _rawBox.compact();

  // TODO stop sync if running?
  Future<void> deleteFromDisk() => _rawBox.deleteFromDisk();

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
}
