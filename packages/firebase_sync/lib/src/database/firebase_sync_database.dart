import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../reading/read_only_store_async.dart';
import '../reading/read_only_store_sync.dart';
import '../storage/storage_factory.dart';
import '../storage/write_storage_entry_json_converter.dart';
import '../writing/read_write_store_async.dart';
import '../writing/read_write_store_sync.dart';
import 'firebase_store_factory.dart';

class NoSyncSupportError extends StateError {
  NoSyncSupportError()
      : super('The storage factory cannot create sync storages!');
}

class FirebaseSyncDatabase {
  final FirebaseDatabase firebaseDatabase;
  final StorageFactory storageFactory;
  final FirebaseStoreFactory firebaseStoreFactory;

  const FirebaseSyncDatabase({
    required this.firebaseDatabase,
    required this.storageFactory,
    required this.firebaseStoreFactory,
  });

  ReadOnlyStoreSync<T> readStoreSync<T extends Object>(
    String path, [
    Map<String, dynamic> extraArgs = const <String, dynamic>{},
  ]) {
    if (!storageFactory.canCreateSyncStore) {
      throw NoSyncSupportError();
    }

    final store = firebaseStoreFactory.createStore<T>(
      firebaseDatabase.rootStore,
      path,
    );
    return ReadOnlyStoreSync(
      firebaseStore: store,
      storage: storageFactory.createStorage(
        firebasePath: path,
        jsonConverter: store,
        sync: true,
        extraArgs: extraArgs,
      ),
    );
  }

  ReadOnlyStoreAsync<T> readStoreAsync<T extends Object>(
    String path, [
    Map<String, dynamic> extraArgs = const <String, dynamic>{},
  ]) {
    final store = firebaseStoreFactory.createStore<T>(
      firebaseDatabase.rootStore,
      path,
    );
    return ReadOnlyStoreAsync(
      firebaseStore: store,
      storage: storageFactory.createStorage(
        firebasePath: path,
        jsonConverter: store,
        sync: false,
        extraArgs: extraArgs,
      ),
    );
  }

  ReadWriteStoreSync<T> writeStoreSync<T extends Object>(
    String path, [
    Map<String, dynamic> extraArgs = const <String, dynamic>{},
  ]) {
    if (!storageFactory.canCreateSyncStore) {
      throw NoSyncSupportError();
    }

    final store = firebaseStoreFactory.createStore<T>(
      firebaseDatabase.rootStore,
      path,
    );
    return ReadWriteStoreSync(
      firebaseStore: store,
      storage: storageFactory.createStorage(
        firebasePath: path,
        jsonConverter: WriteStorageEntryJsonConverter(store),
        sync: true,
        extraArgs: extraArgs,
      ),
    );
  }

  ReadWriteStoreAsync<T> writeStoreAsync<T extends Object>(
    String path, [
    Map<String, dynamic> extraArgs = const <String, dynamic>{},
  ]) {
    final store = firebaseStoreFactory.createStore<T>(
      firebaseDatabase.rootStore,
      path,
    );
    return ReadWriteStoreAsync(
      firebaseStore: store,
      storage: storageFactory.createStorage(
        firebasePath: path,
        jsonConverter: WriteStorageEntryJsonConverter(store),
        sync: true,
        extraArgs: extraArgs,
      ),
    );
  }
}
