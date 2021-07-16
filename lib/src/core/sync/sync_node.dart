import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../crypto/crypto_firebase_store.dart';
import '../store/sync_object_store.dart';

class SyncNode<T extends Object> {
  final JsonConverter<T> jsonConverter;
  final SyncObjectStore<T> localStore;
  final CryptoFirebaseStore remoteStore;

  const SyncNode({
    required this.jsonConverter,
    required this.localStore,
    required this.remoteStore,
  });
}
