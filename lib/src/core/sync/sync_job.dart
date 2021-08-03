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
class SyncJobExecutionResult with _$SyncJobExecutionResult {
  const factory SyncJobExecutionResult.success() = _Success;
  const factory SyncJobExecutionResult.noop() = _Noop;
  const factory SyncJobExecutionResult.next(SyncJob nextJob) = _Next;
}

abstract class SyncJob {
  final _completer = Completer<SyncJobResult>();

  @nonVirtual
  Future<SyncJobResult> get result => _completer.future;

  String get storeName;
  String get key;

  @nonVirtual
  Future<void> call() async {
    if (_completer.isCompleted) {
      return;
    }

    try {
      final result = await execute();
      _completer.complete(result.when(
        success: () => SyncJobResult.success,
        noop: () => SyncJobResult.noop,
        next: (job) => job.result,
      ));
    } catch (e) {
      _completer.complete(SyncJobResult.failure);
      rethrow;
    }
  }

  @nonVirtual
  void abort() {
    // TODO test
    if (!_completer.isCompleted) {
      _completer.complete(SyncJobResult.aborted);
    }
  }

  @nonVirtual
  bool checkConflict(SyncJob other) =>
      storeName == other.storeName && key == other.key;

  @protected
  Future<SyncJobExecutionResult> execute();

  @override
  String toString() => '$runtimeType($storeName:$key)';
}
