import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/sync/sync_mode.dart';

abstract class SyncController<T extends Object> {
  const SyncController._();

  SyncMode get syncMode;
  set syncMode(SyncMode syncMode);

  Future<int> download([Filter? filter]);

  Future<int> upload({bool multipass = true});

  Future<int> reload({
    Filter? filter,
    bool multipass = true,
  });

  Future<MapEntry<String, T>> create(T value);

  Future<void> destroy();
}