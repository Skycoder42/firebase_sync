import 'package:firebase_database_rest/firebase_database_rest.dart';

import 'sync_mode.dart';

abstract class SyncController<T extends Object> {
  const SyncController._(); // coverage:ignore-line

  SyncMode get syncMode;

  Future<void> setSyncMode(SyncMode syncMode);

  Future<int> download({
    Filter? filter,
    bool conflictsTriggerUpload = false,
  });

  Future<int> upload({bool multipass = true});

  Future<int> reload({
    Filter? filter,
    bool multipass = true,
  });

  Future<void> destroy();
}
