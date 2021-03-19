import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../storage/storage.dart';
import '../storage/write_storage_entry.dart';
import '../utils/future_or_x.dart';
import 'implementation/local_async_mixin.dart';
import 'implementation/local_transaction_storage.dart';
import 'implementation/remote_mixin.dart';
import 'write_store_local_async.dart';

class ReadWriteStoreAsync<T extends Object>
    with LocalAsyncMixinBase<T>, LocalAsyncMixin<T>, RemoteMixin<T> {
  @override
  final FirebaseStore<T> firebaseStore;

  @override
  @internal
  late final LocalTransactionStorage<T> transactionStorage;

  @override
  Storage<WriteStorageEntry<T>> get storage => transactionStorage.rawStorage;

  ReadWriteStoreAsync({
    required this.firebaseStore,
    required Storage<WriteStorageEntry<T>> storage,
  }) {
    transactionStorage = LocalTransactionStorage(
      rawStorage: storage,
      conflictResolver: this,
    );
  }

  @override
  Future<TR> transaction<TR>(AsyncTransactionFn<T, TR> transaction) => storage
      .transaction(
        (storage) => transaction(
          ReadWriteStoreAsync(
            firebaseStore: firebaseStore,
            storage: storage,
          ),
        ),
      )
      .toFuture();
}
