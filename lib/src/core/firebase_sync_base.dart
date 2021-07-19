import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/crypto_service.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import 'crypto/crypto_firebase_store.dart';
import 'store/sync_object_store.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_mode.dart';
import 'sync/sync_node.dart';
import 'sync_store.dart';

abstract class FirebaseSyncBase {
  final _jsonConverters =
      <Type, Tuple2<JsonConverter<dynamic>, ConflictResolver<dynamic>>>{};
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

  CryptoService get cryptoService;

  bool isStoreOpen(String name);

  Future<SyncStore<T>> openStore<T extends Object>(
    String name, {
    SyncMode syncMode = SyncMode.sync,
  });

  SyncStore<T> store<T extends Object>(String name);

  @mustCallSuper
  Future<void> close() async {
    _syncNodes.clear();
    await syncEngine.stop();
  }

  bool isConverterRegistered<T extends Object>() =>
      _jsonConverters.containsKey(T);

  void registerConverter<T extends Object>({
    required JsonConverter<T> converter,
    ConflictResolver<T>? conflictResolver,
    bool override = false,
  }) {
    _jsonConverters.update(
      T,
      (_) => override
          ? Tuple2(
              converter,
              conflictResolver ?? const ConflictResolver(),
            )
          : throw StateError('JSON-Converter already registered for type $T'),
      ifAbsent: () => Tuple2(
        converter,
        conflictResolver ?? const ConflictResolver(),
      ),
    );
  }

  @protected
  SyncNode<T> createSyncNode<T extends Object>(
    String name,
    SyncObjectStore<T> localStore,
  ) {
    final converterTuple = _getConverter<T>();
    return _syncNodes.putIfAbsent(
      name,
      () => SyncNode(
        storeName: name,
        jobScheduler: syncEngine,
        cryptoService: cryptoService,
        jsonConverter: converterTuple.item1,
        conflictResolver: converterTuple.item2,
        localStore: localStore,
        remoteStore: CryptoFirebaseStore(
          parent: rootStore,
          name: name,
        ),
      ),
    ) as SyncNode<T>;
  }

  @protected
  SyncNode<T> getSyncNode<T extends Object>(String name) {
    final syncNode = _syncNodes[name];
    if (syncNode == null) {
      throw StateError('createSyncNode must be called before getSyncNode');
    }

    return syncNode as SyncNode<T>;
  }

  Tuple2<JsonConverter<T>, ConflictResolver<T>>
      _getConverter<T extends Object>() {
    final converterTuple = _jsonConverters[T];
    if (converterTuple == null) {
      throw StateError(
        'No converter for type $T. Register one via registerConverter',
      );
    }

    return Tuple2(
      converterTuple.item1 as JsonConverter<T>,
      converterTuple.item2 as ConflictResolver<T>,
    );
  }
}
