import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../storage/storage.dart';
import '../store_transaction.dart';

@internal
class ReadOnlyStoreTransaction<T extends Object>
    implements StoreTransaction<T> {
  final Storage<T> storage;
  final FirebaseTransaction<T> storeTransaction;

  bool _completed = false;

  ReadOnlyStoreTransaction(this.storage, this.storeTransaction);

  @override
  String get key => storeTransaction.key;

  @override
  T? get value => storeTransaction.value;

  @override
  Future<T?> commitUpdate(T data) async {
    _complete();
    await storeTransaction.commitUpdate(data);
    await storage.writeEntry(key, data);
  }

  @override
  Future<void> commitDelete() async {
    _complete();
    await storeTransaction.commitDelete();
    await storage.deleteEntry(key);
  }

  void _complete() {
    if (_completed) {
      throw AlreadyComittedError();
    }
    _completed = true;
  }
}
