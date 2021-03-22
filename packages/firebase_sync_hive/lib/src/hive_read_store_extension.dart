import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import 'hive_storage_extension.dart';

extension HiveReadStoreExtension on HiveInterface {
  ReadOnlyStoreAsync<T> readStoreAsync<T extends Object>({
    required String name,
    required FirebaseStore<T> firebaseStore,
    bool lazyStorage = false,
    bool awaitBoxOperations = false,
  }) =>
      ReadOnlyStoreAsync(
        firebaseStore: firebaseStore,
        storage: lazyStorage
            ? this.lazyStorage(
                name,
                jsonConverter: firebaseStore,
                awaitBoxOperations: awaitBoxOperations,
              )
            : storage(
                name,
                jsonConverter: firebaseStore,
                awaitBoxOperations: awaitBoxOperations,
              ),
      );

  ReadOnlyStoreSync<T> readStoreSync<T extends Object>({
    required String name,
    required FirebaseStore<T> firebaseStore,
  }) =>
      ReadOnlyStoreSync(
        firebaseStore: firebaseStore,
        storage: storage(
          name,
          jsonConverter: firebaseStore,
          awaitBoxOperations: false,
        ),
      );
}
