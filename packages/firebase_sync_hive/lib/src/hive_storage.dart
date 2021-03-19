import 'dart:async';

import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

import 'hive_storage_base.dart';
import 'hive_transaction.dart';

class HiveStorage<T extends Object> extends HiveStorageBase<T> {
  HiveStorage({
    required Box<T> box,
    bool awaitBoxOperations = false,
  }) : super(
          box: box,
          awaitBoxOperations: awaitBoxOperations,
        );

  @override
  Box<T> get box => super.box as Box<T>;

  @override
  bool get isSync => !awaitBoxOperations;

  @override
  FutureOr<Map<String, T>> entries() => box.toMap().cast();

  @override
  FutureOr<T?> readEntry(String key) => box.get(key);

  @override
  FutureOr<TR> transaction<TR>(TransactionFn<T, TR> transaction) =>
      isSync ? transaction(this) : HiveTransaction(this).call(transaction);
}
