import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';

import 'sync_job.dart';

part 'executable_sync_job.freezed.dart';

@freezed
class ExecutionResult with _$ExecutionResult {
  const factory ExecutionResult.modified() = _Modified;
  const factory ExecutionResult.noop() = _Noop;
  const factory ExecutionResult.continued(SyncJob nextJob) = _Continued;
}

abstract class ExecutableSyncJob extends SyncJob {
  @nonVirtual
  Future<SyncJob?> execute() async {
    if (completer.isCompleted) {
      return null;
    }

    try {
      final result = await executeImpl();
      completer.complete(
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
      completer.complete(SyncJobResult.failure);
      rethrow;
    }
  }

  @protected
  Future<ExecutionResult> executeImpl();
}
