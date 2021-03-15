import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import 'hive_storage.dart';
import 'lazy_hive_storage.dart';

extension FirebaseSyncHiveExtension on HiveInterface {
  static final _rawStorages = Expando<List<Type>>('FirebaseSyncHiveExtension');

  void registerRawStorage<T>({
    TypeAdapter<T>? adapter,
    bool internal = false,
    bool override = false,
  }) {
    _rawStorages[this] ??= [];
    _rawStorages[this]!.add(T);
    if (adapter != null) {
      registerAdapter(adapter, internal: internal, override: override);
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
