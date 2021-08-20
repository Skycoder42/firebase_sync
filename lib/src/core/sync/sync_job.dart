import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';

part 'sync_job.freezed.dart';

enum SyncJobResult {
  success,
  noop,
  failure,
  aborted,
}

@freezed
class ExecutionResult with _$ExecutionResult {
  const factory ExecutionResult.modified() = _Modified;
  const factory ExecutionResult.noop() = _Noop;
  const factory ExecutionResult.continued(SyncJob nextJob) = _Continued;
}

abstract class SyncJob {
  final _completer = Completer<SyncJobResult>();

  @nonVirtual
  Future<SyncJobResult> get result => _completer.future;

  @nonVirtual
  Future<SyncJob?> call() async {
    if (_completer.isCompleted) {
      return null;
    }

    try {
      final result = await execute();
      _completer.complete(
        result.when(
          modified: () => SyncJobResult.success,
          noop: () => SyncJobResult.noop,
          continued: (job) => job.result,
        ),
      );

      return result.maybeWhen(
        continued: (job) => job,
        orElse: () => null,
      );
    } catch (e) {
      _completer.complete(SyncJobResult.failure);
      rethrow;
    }
  }

  @nonVirtual
  void abort() {
    if (!_completer.isCompleted) {
      _completer.complete(SyncJobResult.aborted);
    }
  }

  @protected
  Future<ExecutionResult> execute();
}

abstract class SyncJobCollection {
  factory SyncJobCollection.single(SyncJob syncJob) = _SingleSyncJobCollection;

  Stream<SyncJobResult> get results;

  Stream<SyncJob> expand();
}

class _SingleSyncJobCollection implements SyncJobCollection {
  final SyncJob syncJob;

  _SingleSyncJobCollection(this.syncJob);

  @override
  Stream<SyncJob> expand() => Stream.value(syncJob);

  @override
  Stream<SyncJobResult> get results => Stream.fromFuture(syncJob.result);
}
