import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../storage/storage.dart';
import 'implementation/local_async_mixing.dart';
import 'implementation/remote_mixin.dart';
import 'read_store_remote.dart';

class ReadOnlyStoreAsync<T extends Object>
    with LocalAsyncMixinBase<T>, LocalAsyncMixin<T>, RemoteMixin<T> {
  @override
  final FirebaseStore<T> firebaseStore;

  @override
  final Storage<T> storage;

  @override
  ReloadStrategy reloadStrategy = ReloadStrategy.compareKey;

  ReadOnlyStoreAsync({
    required this.firebaseStore,
    required this.storage,
  });
}
