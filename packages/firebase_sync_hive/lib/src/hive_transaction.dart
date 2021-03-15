import 'package:firebase_sync/firebase_sync.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import '../firebase_sync_hive.dart';

@internal
class HiveTransaction<T extends Object> {
  static final _locks = Expando<Lock>();

  final HiveStorageBase<T> storage;

  const HiveTransaction(this.storage);

  Future<void> call(TransactionFn<T> transaction) {
    _locks[storage.box] ??= Lock(reentrant: true);
    return _locks[storage.box]!.synchronized(() => transaction(storage));
  }
}
