import 'package:firebase_sync/firebase_sync.dart';
import 'package:sembast/sembast.dart';

import '../firebase_sync_sembast.dart';

extension SembastLocalReadStoreExtensions<T extends Object>
    on LocalReadStore<T> {
  Future<Map<String, T>> query(Finder finder) {
    final dynamic storage = (this as dynamic).storage;
    if (storage == null || storage is! SembastStorage<T>) {
      throw UnsupportedError(
        'Can only use Sembast extensions on a store that is backed by asembast',
      );
    }
    return storage.query(finder);
  }
}
