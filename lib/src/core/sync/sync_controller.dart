import 'package:firebase_database_rest/firebase_database_rest.dart';

import 'sync_error.dart';
import 'sync_job.dart';
import 'sync_mode.dart';

abstract class SyncController<T extends Object> {
  const SyncController._(); // coverage:ignore-line

  Stream<SyncError> get syncErrors;

  SyncMode get syncMode;
  set syncMode(SyncMode syncMode);

  Filter? get syncFilter;
  set syncFilter(Filter? filter);

  bool get autoRenew;
  set autoRenew(bool autoRenew);

  Future<SyncJobResult> download({
    Filter? filter,
    bool conflictsTriggerUpload = false,
  });

  Future<SyncJobResult> upload({bool multipass = true});

  Future<SyncJobResult> reload({
    Filter? filter,
    bool multipass = true,
  });
}

extension SyncControllerX on SyncController {
  bool get isDownsyncActive =>
      syncMode == SyncMode.download || syncMode == SyncMode.sync;

  bool get isUpssyncActive =>
      syncMode == SyncMode.upload || syncMode == SyncMode.sync;
}
