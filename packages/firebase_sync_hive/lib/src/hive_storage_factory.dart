import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import '../firebase_sync_hive.dart';
import 'hive_storage_extension.dart';

class HiveStorageFactory implements StorageFactory {
  static const awaitBoxOperationsInfo = ExtraArgInfo(
    name: 'awaitBoxOperations',
    type: bool,
    defaultValue: false,
  );

  static const lazyStorageInfo = ExtraArgInfo(
    name: 'lazyStorage',
    type: bool,
    defaultValue: false,
  );

  final HiveInterface hiveInterface;

  HiveStorageFactory(this.hiveInterface);

  @override
  bool get canCreateSyncStore => true;

  @override
  Iterable<ExtraArgInfo> get extraArgs => const [
        awaitBoxOperationsInfo,
        lazyStorageInfo,
      ];

  @override
  Storage<T> createStorage<T extends Object>({
    required String firebasePath,
    required JsonConverter<T> jsonConverter,
    bool sync = false,
    Map<String, dynamic> extraArgs = const <String, dynamic>{},
  }) {
    final lazyStorage = lazyStorageInfo.extractArg<bool>(extraArgs);
    if (sync && lazyStorage) {
      throw ArgumentError(
        'Cannot set both, "sync" and "lazyStorage" - '
        'a sync storage cannot be lazy',
      );
    }
    final awaitBoxOperations =
        awaitBoxOperationsInfo.extractArg<bool>(extraArgs);
    if (sync && awaitBoxOperations) {
      throw ArgumentError(
        'Cannot set both, "sync" and "awaitBoxOperations" - '
        'a sync storage cannot await writes to the box',
      );
    }

    if (lazyStorage) {
      return hiveInterface.lazyStorage(
        firebasePath,
        jsonConverter: jsonConverter,
        awaitBoxOperations: awaitBoxOperations,
      );
    } else {
      return hiveInterface.storage(
        firebasePath,
        jsonConverter: jsonConverter,
        awaitBoxOperations: awaitBoxOperations,
      );
    }
  }
}

extension HiveInstanceFactoryX on HiveInterface {
  StorageFactory get storageFactory => HiveStorageFactory(this);
}

extension StorageFactoryHiveX on StorageFactory {
  Storage<T> createHiveStorage<T extends Object>({
    required String firebasePath,
    required JsonConverter<T> jsonConverter,
    bool sync = false,
    bool lazyStorage = false,
    bool awaitBoxOperations = false,
  }) =>
      createStorage(
        firebasePath: firebasePath,
        jsonConverter: jsonConverter,
        sync: sync,
        extraArgs: <String, dynamic>{
          HiveStorageFactory.awaitBoxOperationsInfo.name: awaitBoxOperations,
          HiveStorageFactory.lazyStorageInfo.name: lazyStorage,
        },
      );
}
