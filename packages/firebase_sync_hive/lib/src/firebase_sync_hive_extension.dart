import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import 'hive_storage.dart';
import 'lazy_hive_storage.dart';
import 'write_storage_entry_type_adapter.dart';

extension FirebaseSyncHiveExtension on HiveInterface {
  static final _rawStorages = Expando<List<Type>>('FirebaseSyncHiveExtension');

  void _addRawType<T>() {
    _rawStorages[this] ??= [];
    _rawStorages[this]!.add(T);
  }

  void registerRawStorage<T extends Object>({
    TypeAdapter<T>? adapter,
    bool writable = true,
    bool internal = false,
    bool override = false,
  }) {
    _addRawType<T>();
    if (writable) {
      _addRawType<WriteStorageEntry<T>>();
    }

    if (adapter != null) {
      registerAdapter(adapter, internal: internal, override: override);
      if (writable) {
        registerAdapter(
          WriteStorageEntryTypeAdapter.wrap(adapter),
          internal: internal,
          override: override,
        );
      }
    }
  }

  bool isRawStorage<T extends Object>() =>
      _rawStorages[this]?.contains(T) ?? false;

  Storage<T> storage<T extends Object>(
    String name, {
    JsonConverter<T>? jsonConverter,
    bool awaitBoxOperations = false,
  }) {
    if (isRawStorage<T>()) {
      return HiveStorage<T>(
        box: box<T>(name),
        awaitBoxOperations: awaitBoxOperations,
      );
    } else {
      return JsonStorage(
        jsonConverter: ArgumentError.checkNotNull(
          jsonConverter,
          'jsonConverter',
        ),
        rawStorage: HiveStorage(
          box: box(name),
          awaitBoxOperations: awaitBoxOperations,
        ),
      );
    }
  }

  Storage<T> lazyStorage<T extends Object>(
    String name, {
    JsonConverter<T>? jsonConverter,
    bool awaitBoxOperations = false,
  }) {
    if (isRawStorage<T>()) {
      return LazyHiveStorage<T>(
        box: lazyBox<T>(name),
        awaitBoxOperations: awaitBoxOperations,
      );
    } else {
      return JsonStorage(
        jsonConverter: ArgumentError.checkNotNull(
          jsonConverter,
          'jsonConverter',
        ),
        rawStorage: LazyHiveStorage(
          box: lazyBox(name),
          awaitBoxOperations: awaitBoxOperations,
        ),
      );
    }
  }
}
