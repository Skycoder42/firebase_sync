import 'dart:async';

import 'package:meta/meta.dart';

import 'executable_sync_job.dart';
import 'expandable_sync_job.dart';

enum SyncJobResult {
  noop,
  success,
  aborted,
  failure,
}

abstract class SyncJob {
  @internal
  final completer = Completer<SyncJobResult>();

  @nonVirtual
  Future<SyncJobResult> get result => completer.future;

  @nonVirtual
  void abort() {
    if (!completer.isCompleted) {
      completer.complete(SyncJobResult.aborted);
    }
  }
}

extension SyncJobResultX on SyncJobResult {
  SyncJobResult combine(SyncJobResult other) =>
      other.index > index ? other : this;
}

extension SyncJobExpandX on SyncJob {
  Stream<ExecutableSyncJob> expand() {
    if (this is ExpandableSyncJob) {
      return (this as ExpandableSyncJob).expand();
    } else {
      return Stream.value(this as ExecutableSyncJob);
    }
  }
}
