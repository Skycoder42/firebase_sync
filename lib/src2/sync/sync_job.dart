import 'dart:async';

import 'package:firebase_sync/src/sync/job_scheduler.dart';
import 'package:meta/meta.dart';

abstract class SyncJob {
  final _completer = Completer<bool>();

  @nonVirtual
  Future<bool> get result => _completer.future;

  String get hashedKey;

  @nonVirtual
  Future<void> call(JobScheduler scheduler) async {
    try {
      await execute(scheduler);
      _completer.complete(true);
    } catch (e) {
      _completer.complete(false);
      rethrow;
    }
  }

  @protected
  Future<void> execute(JobScheduler scheduler);
}
