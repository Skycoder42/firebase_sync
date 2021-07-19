import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';

import '../crypto/crypto_firebase_store.dart';
import '../crypto/crypto_service.dart';
import '../store/sync_object_store.dart';
import 'job_scheduler.dart';

class SyncNode<T extends Object> {
  final String storeName;
  final JobScheduler jobScheduler;
  final CryptoService cryptoService;
  final JsonConverter<T> jsonConverter;
  final ConflictResolver<T> conflictResolver;
  final SyncObjectStore<T> localStore;
  final CryptoFirebaseStore remoteStore;

  const SyncNode({
    required this.storeName,
    required this.jobScheduler,
    required this.cryptoService,
    required this.jsonConverter,
    required this.conflictResolver,
    required this.localStore,
    required this.remoteStore,
  });
}
