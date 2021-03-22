import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import 'hive_storage_extension.dart';

extension HiveWriteStoreExtension on HiveInterface {
  ReadWriteStoreAsync<T> readStoreAsync<T extends Object>({
    required String name,
    required FirebaseStore<T> firebaseStore,
    bool lazyStorage = false,
    bool awaitBoxOperations = false,
  }) =>
      ReadWriteStoreAsync(
        firebaseStore: firebaseStore,
        storage: lazyStorage
            ? this.lazyStorage(
                name,
                jsonConverter: WriteStorageEntryJsonConverter(firebaseStore),
                awaitBoxOperations: awaitBoxOperations,
              )
            : storage(
                name,
                jsonConverter: WriteStorageEntryJsonConverter(firebaseStore),
                awaitBoxOperations: awaitBoxOperations,
              ),
      );

  ReadWriteStoreSync<T> readStoreSync<T extends Object>({
    required String name,
    required FirebaseStore<T> firebaseStore,
  }) =>
      ReadWriteStoreSync(
        firebaseStore: firebaseStore,
        storage: storage(
          name,
          jsonConverter: WriteStorageEntryJsonConverter(firebaseStore),
          awaitBoxOperations: false,
        ),
      );
}
