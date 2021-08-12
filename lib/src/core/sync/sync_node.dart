import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:uuid/uuid.dart';

import '../crypto/crypto_firebase_store.dart';
import '../crypto/data_encryptor.dart';
import '../store/sync_object_store.dart';
import 'conflict_resolver.dart';
import 'job_scheduler.dart';

class SyncNode<T extends Object> {
  final String storeName;
  final JobScheduler jobScheduler;
  final Uuid uuidGenerator;
  final DataEncryptor dataEncryptor;
  final JsonConverter<T> jsonConverter;
  final ConflictResolver<T> conflictResolver;
  final SyncObjectStore<T> localStore;
  final CryptoFirebaseStore remoteStore;

  const SyncNode({
    required this.storeName,
    required this.jobScheduler,
    required this.uuidGenerator,
    required this.dataEncryptor,
    required this.jsonConverter,
    required this.conflictResolver,
    required this.localStore,
    required this.remoteStore,
  });
}
