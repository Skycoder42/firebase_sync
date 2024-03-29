import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../crypto/crypto_firebase_store.dart';
import '../crypto/data_encryptor.dart';
import '../store/sync_object_store.dart';
import 'conflict_resolver.dart';
import 'sync_job_executor.dart';

class SyncNode<T extends Object> {
  final String storeName;
  final SyncJobExecutor syncJobExecutor;
  final DataEncryptor dataEncryptor;
  final JsonConverter<T> jsonConverter;
  final ConflictResolver<T> conflictResolver;
  final SyncObjectStore<T> localStore;
  final CryptoFirebaseStore remoteStore;
  final StreamSubscription<void> errorSubscription;

  const SyncNode({
    required this.storeName,
    required this.syncJobExecutor,
    required this.dataEncryptor,
    required this.jsonConverter,
    required this.conflictResolver,
    required this.localStore,
    required this.remoteStore,
    required this.errorSubscription,
  });

  Future<void> close() async {
    await Future.wait([
      syncJobExecutor.close(),
      errorSubscription.cancel(),
    ]);
    dataEncryptor.dispose();
  }
}
