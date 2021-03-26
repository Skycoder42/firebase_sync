import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../storage/storage.dart';
import 'implementation/local_sync_mixin.dart';
import 'implementation/remote_mixin.dart';
import 'read_store_remote.dart';

class ReadOnlyStoreSync<T extends Object>
    with LocalSyncMixinBase<T>, LocalSyncMixin<T>, RemoteMixin<T> {
  @override
  final FirebaseStore<T> firebaseStore;

  @override
  final Storage<T> storage;

  @override
  ReloadStrategy reloadStrategy = ReloadStrategy.compareKey;

  ReadOnlyStoreSync({
    required this.firebaseStore,
    required this.storage,
  }) : assert(
          storage.isSync,
          'you can only use $ReadOnlyStoreSync with synchronous storages',
        );

  @override
  void onInvalidPath(String path) {}
}
