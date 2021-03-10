import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../storage.dart';
import '../store_transaction.dart';
import 'read_write_lock.dart';

@internal
class ReadOnlyStoreTransaction<T> implements StoreTransaction<T> {
  final Storage<T> storage;
  final FirebaseTransaction<T> storeTransaction;
  final ReadWriteLock lock;

  bool _completed = false;

  ReadOnlyStoreTransaction(this.storage, this.storeTransaction, this.lock);

  @override
  String get key => storeTransaction.key;

  @override
  T? get value => storeTransaction.value;

  @override
  Future<T?> commitUpdate(T data) async {
    _complete();
    try {
      await storeTransaction.commitUpdate(data);
      await storage.writeEntry(key, data);
    } finally {
      lock.release();
    }
  }

  @override
  Future<void> commitDelete() async {
    _complete();
    try {
      await storeTransaction.commitDelete();
      await storage.deleteEntry(key);
    } finally {
      lock.release();
    }
  }

  @override
  void abort() {
    _complete();
    lock.release();
  }

  void _complete() {
    if (_completed) {
      throw AlreadyComittedError();
    }
    _completed = true;
  }
}
