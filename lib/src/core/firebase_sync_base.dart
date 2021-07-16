import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import 'crypto/crypto_firebase_store.dart';
import 'store/sync_object_store.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_mode.dart';
import 'sync/sync_node.dart';
import 'sync_store.dart';

abstract class FirebaseSyncBase {
  final FirebaseStore<dynamic> rootStore;

  final Map<Type, JsonConverter<dynamic>> _jsonConverters = {};
  final Map<String, SyncNode<dynamic>> _syncNodes = {};

  final SyncEngine syncEngine;

  FirebaseSyncBase({
    required this.rootStore,
    int parallelJobs = SyncEngine.defaultParallelJobs,
    bool startSync = true,
  }) : syncEngine = SyncEngine(
          parallelJobs: parallelJobs,
        ) {
    if (startSync) {
      syncEngine.start();
    }
  }

  bool isStoreOpen(String name);

  Future<SyncStore<T>> openStore<T extends Object>(
    String name, {
    SyncMode syncMode = SyncMode.sync,
  });

  SyncStore<T> store<T extends Object>(String name);

  @mustCallSuper
  Future<void> close() async {
    _syncNodes.clear();
    await syncEngine.stop(); // TODO use "done" future
  }

  bool isConverterRegistered<T extends Object>() =>
      _jsonConverters.containsKey(T);

  void registerConverter<T extends Object>(
    JsonConverter<T> converter, {
    bool override = false,
  }) {
    _jsonConverters.update(
      T,
      (_) => override
          ? converter
          : throw StateError(
              'Converter for $T already registered!'), // TODO proper exception
      ifAbsent: () => converter,
    );
  }

  @protected
  SyncNode<T> createSyncNode<T extends Object>(
    String name,
    SyncObjectStore<T> localStore,
  ) {
    return _syncNodes.putIfAbsent(
      name,
      () => SyncNode(
        jsonConverter: _getConverter<T>(),
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
      throw StateError(
        'No syncNode for store named "$name". Create one via createSyncNode', // TODO proper exception
      );
    }

    return syncNode as SyncNode<T>;
  }

  JsonConverter<T> _getConverter<T extends Object>() {
    final converter = _jsonConverters[T];
    if (converter == null) {
      throw StateError(
        'No converter for type $T. Register one via registerConverter', // TODO proper exception
      );
    }

    return converter as JsonConverter<T>;
  }
}
