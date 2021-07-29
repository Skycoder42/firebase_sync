import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import 'crypto/crypto_firebase_store.dart';
import 'crypto/data_encryptor.dart';
import 'crypto/key_hasher.dart';
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
    bool startSync = true,
  }) : syncEngine = SyncEngine(
          parallelJobs: parallelJobs,
        ) {
    if (startSync) {
      syncEngine.start();
    }
  }

  FirebaseStore<dynamic> get rootStore;

  DataEncryptor get cryptoService;

  KeyHasher get keyHasher;

  bool isStoreOpen(String name);

  Future<SyncStore<T>> openStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required dynamic storageConverter,
    SyncMode syncMode = SyncMode.sync,
    ConflictResolver<T>? conflictResolver,
    bool hashKeys = false,
  });

  SyncStore<T> store<T extends Object>(String name);

  @mustCallSuper
  Future<void> close() async {
    _syncNodes.clear();
    await syncEngine.stop();
  }

  @protected
  SyncNode<T> createSyncNode<T extends Object>({
    required String storeName,
    required SyncObjectStore<T> localStore,
    required JsonConverter<T> jsonConverter,
    ConflictResolver<T>? conflictResolver,
    KeyHasher? keyHasher,
  }) =>
      _syncNodes.putIfAbsent(
        storeName,
        () => SyncNode(
          storeName: storeName,
          jobScheduler: syncEngine,
          keyHasher: keyHasher,
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
}
