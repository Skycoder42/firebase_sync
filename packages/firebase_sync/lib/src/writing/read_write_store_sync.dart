import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../storage/storage.dart';
import '../storage/write_storage_entry.dart';
import '../utils/future_or_x.dart';
import 'implementation/local_sync_mixin.dart';
import 'implementation/local_transaction_storage.dart';
import 'implementation/remote_mixin.dart';
import 'write_store_local_sync.dart';

class ReadWriteStoreSync<T extends Object>
    with LocalSyncMixinBase<T>, LocalSyncMixin<T>, RemoteMixin<T> {
  @override
  final FirebaseStore<T> firebaseStore;

  @override
  @internal
  late final LocalTransactionStorage<T> transactionStorage;

  @override
  Storage<WriteStorageEntry<T>> get storage => transactionStorage.rawStorage;

  ReadWriteStoreSync({
    required this.firebaseStore,
    required Storage<WriteStorageEntry<T>> storage,
  }) {
    transactionStorage = LocalTransactionStorage(
      rawStorage: storage,
      conflictResolver: this,
    );
  }

  @override
  TR transaction<TR>(SyncTransactionFn<T, TR> transaction) => storage
      .transaction(
        (storage) => transaction(
          ReadWriteStoreSync(
            firebaseStore: firebaseStore,
            storage: storage,
          ),
        ),
      )
      .sync;
}
