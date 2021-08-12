import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'crypto/crypto_firebase_store.dart';
import 'crypto/data_encryptor.dart';
import 'store/sync_object_store.dart';
import 'sync/conflict_resolver.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_mode.dart';
import 'sync/sync_node.dart';
import 'sync_store.dart';

abstract class FirebaseSyncBase {
  final _syncNodes = <String, SyncNode<dynamic>>{};

  final SyncEngine syncEngine;

  FirebaseSyncBase({
    int parallelJobs = SyncEngine.defaultParallelJobs,
  }) : syncEngine = SyncEngine(
          parallelJobs: parallelJobs,
        );

  FirebaseStore<dynamic> get rootStore;

  DataEncryptor get cryptoService;

  bool isStoreOpen(String name);

  Future<SyncStore<T>> openStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required dynamic storageConverter,
    SyncMode syncMode = SyncMode.sync,
    ConflictResolver<T>? conflictResolver,
  });

  SyncStore<T> store<T extends Object>(String name);

  @mustCallSuper
  Future<void> close() async {
    _syncNodes.clear();
    await syncEngine.dispose();
  }

  @protected
  SyncNode<T> createSyncNode<T extends Object>({
    required String storeName,
    required SyncObjectStore<T> localStore,
    required JsonConverter<T> jsonConverter,
    ConflictResolver<T>? conflictResolver,
  }) =>
      _syncNodes.putIfAbsent(
        storeName,
        () => SyncNode(
          storeName: storeName,
          uuidGenerator: Uuid(options: <String, dynamic>{
            'grng': () => cryptoService.generateRandom(16),
          }),
          jobScheduler: syncEngine,
          dataEncryptor: cryptoService,
          jsonConverter: jsonConverter,
          conflictResolver: conflictResolver ?? const ConflictResolver(),
          localStore: localStore,
          remoteStore: CryptoFirebaseStore(
            parent: rootStore,
            name: storeName,
          ),
        ),
      ) as SyncNode<T>;

  @protected
  SyncNode<T> getSyncNode<T extends Object>(String storeName) {
    final syncNode = _syncNodes[storeName];
    if (syncNode == null) {
      throw StateError('createSyncNode must be called before getSyncNode');
    }

    return syncNode as SyncNode<T>;
  }

  @protected
  void closeSyncNode(String storeName) {
    _syncNodes.remove(storeName);
  }
}
