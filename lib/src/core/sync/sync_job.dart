import 'dart:async';

import 'package:meta/meta.dart';

import 'job_scheduler.dart';

enum SyncJobResult {
  success,
  noop,
  failure,
}

abstract class SyncJob {
  final _completer = Completer<SyncJobResult>();

  @nonVirtual
  Future<SyncJobResult> get result => _completer.future;

  String get storeName;
  String get hashedKey;

  @nonVirtual
  Future<void> call(JobScheduler scheduler) => Future(() async {
        try {
          final modified = await execute(scheduler);
          _completer.complete(
            modified ? SyncJobResult.success : SyncJobResult.noop,
          );
        } catch (e) {
          _completer.complete(SyncJobResult.failure);
          rethrow;
        }
      });

  @nonVirtual
  bool checkConflict(SyncJob other) =>
      storeName == other.storeName && hashedKey == other.hashedKey;

  @protected
  Future<bool> execute(JobScheduler scheduler);
}
