import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../store_transaction.dart';

enum ReloadStrategy {
  clear,
  compareKey,
  compareValue,
}

abstract class ReadStoreRemote<T extends Object> {
  const ReadStoreRemote._();

  Future<void> reload([Filter? filter]);

  Future<StreamSubscription<void>> sync({
    Filter? filter,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  StreamSubscription<void> syncRenewed({
    FutureOr<Filter> Function()? onRenewFilter,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  Future<T?> fetch(String key);

  Future<String> create(T value);

  Future<void> store(String key, T value);

  Future<T?> patch(String key, Map<String, dynamic> updateFields);

  Future<void> remove(String key);

  Future<void> destroy(String key);

  Future<StoreTransaction<T>> transaction(String key);
}
