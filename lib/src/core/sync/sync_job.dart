import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';

part 'sync_job.freezed.dart';

enum SyncJobResult {
  success,
  noop,
  failure,
}

@freezed
class SyncJobExecutionResult with _$SyncJobExecutionResult {
  // ignore: avoid_positional_boolean_parameters
  const factory SyncJobExecutionResult(bool result) =
      _Default; // TODO split into 2
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
    try {
      final modified = await execute();
      _completer.complete(modified.when(
        (result) => result ? SyncJobResult.success : SyncJobResult.noop,
        next: (job) => job.result,
      ));
    } catch (e) {
      _completer.complete(SyncJobResult.failure);
      rethrow;
    }
  }

  @nonVirtual
  bool checkConflict(SyncJob other) =>
      storeName == other.storeName && key == other.key;

  @protected
  Future<SyncJobExecutionResult> execute();
}
