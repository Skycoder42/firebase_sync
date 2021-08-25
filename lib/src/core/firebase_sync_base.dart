import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import 'crypto/crypto_firebase_store.dart';
import 'crypto/data_encryptor.dart';
import 'offline_store.dart';
import 'store/store.dart';
import 'store/sync_object_store.dart';
import 'sync/conflict_resolver.dart';
import 'sync/sync_error.dart';
import 'sync/sync_job_executor.dart';
import 'sync/sync_mode.dart';
import 'sync/sync_node.dart';
import 'sync_store.dart';

typedef StoreClosedFn = void Function();
typedef CreateStoreFn<TData extends Object, TStore extends Store<TData>>
    = FutureOr<TStore> Function(StoreClosedFn onClosed);

abstract class FirebaseSyncBase {
  final _stores = <String, Store<dynamic>>{};
  final _errorStreamController =
      StreamController<MapEntry<String, SyncError>>.broadcast();

  FirebaseStore<dynamic> get rootStore;

  Stream<MapEntry<String, SyncError>> get syncErrors =>
      _errorStreamController.stream;

  bool isStoreOpen(String name) => _stores.containsKey(name);

  Future<SyncStore<T>> openStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required dynamic storageConverter,
    SyncMode syncMode = SyncMode.sync,
    ConflictResolver<T>? conflictResolver,
  });

  SyncStore<T> store<T extends Object>(String name) => getStore(name);

  Future<OfflineStore<T>> openOfflineStore<T extends Object>({
    required String name,
    required dynamic storageConverter,
  });

  OfflineStore<T> offlineStore<T extends Object>(String name) => getStore(name);

  @mustCallSuper
  Future<void> close() async {
    await Future.wait(_stores.values.map((store) => store.close()));
    _stores.clear();

    await _errorStreamController.close();
  }

  @protected
  Future<TStore> createStore<TData extends Object, TStore extends Store<TData>>(
    String storeName,
    CreateStoreFn<TData, TStore> onCreateStore,
  ) async {
    if (_stores.containsKey(storeName)) {
      throw StateError(
        'A store with the name "$storeName" has already been opened.',
      );
    }
    return _stores[storeName] = await onCreateStore(
      () => _stores.remove(storeName),
    );
  }

  @protected
  TStore getStore<TData extends Object, TStore extends Store<TData>>(
    String storeName,
  ) {
    final store = _stores[storeName];

    if (store == null) {
      throw StateError(
        'A store with the name "$storeName" '
        'has not been opend or was already closed.',
      );
    }

    if (store is! TStore) {
      throw StateError(
        'Store with name "$storeName" is of type ${store.runtimeType}, '
        'but a store of type $TStore was requested.',
      );
    }

    return store;
  }

  @protected
  SyncNode<T> createSyncNode<T extends Object>({
    required String storeName,
    required SyncObjectStore<T> localStore,
    required JsonConverter<T> jsonConverter,
    required DataEncryptor dataEncryptor,
    ConflictResolver<T>? conflictResolver,
  }) {
    final syncNode = SyncNode<T>(
      storeName: storeName,
      syncJobExecutor: SyncJobExecutor(),
      dataEncryptor: dataEncryptor,
      jsonConverter: jsonConverter,
      conflictResolver: conflictResolver ?? const ConflictResolver(),
      localStore: localStore,
      remoteStore: CryptoFirebaseStore(
        parent: rootStore,
        name: storeName,
      ),
    );

    // subscription will never be canceled
    syncNode.syncJobExecutor.syncErrors.listen(
      (error) => _errorStreamController.add(MapEntry(storeName, error)),
      onError: _errorStreamController.addError,
      cancelOnError: false,
    );

    return syncNode;
  }
}
