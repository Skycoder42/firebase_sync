import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../local_store_event.dart';
import '../storage/write_storage.dart';
import '../store_transaction.dart';
import 'local_write_store.dart';

abstract class ReadWriteStore<T extends Object> implements LocalWriteStore<T> {
  final FirebaseStore<T> firebaseStore;
  final WriteStorage<T> storage;

  const ReadWriteStore(this.firebaseStore, this.storage);

  // local
  @override
  Future<int> length();

  @override
  Future<bool> isEmpty();

  @override
  Future<bool> isNotEmpty();

  @override
  Future<List<String>> keys();

  @override
  Future<Map<String, T>> asMap();

  @override
  Future<T?> value(String key);

  @override
  Future<Stream<LocalStoreEvent<T>>> watch();

  @override
  Future<Stream<T?>> watchEntry(String key);

  @override
  Future<void> clear();

  // remote
  Future<void> download([Filter? filter]);

  Future<void> upload({bool multipass = true});

  Future<void> relpad({
    Filter? filter,
    bool multipass = true,
  });

  Future<StreamSubscription<void>> syncDownload({
    Filter? filter,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  StreamSubscription<void> syncDownloadRenewed({
    FutureOr<Filter> Function()? onRenewFilter,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  Future<StreamSubscription<void>> syncUpload({
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

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

  Future<StoreTransaction<T>> transaction(String key);

  Future<String> create(T value);
}
