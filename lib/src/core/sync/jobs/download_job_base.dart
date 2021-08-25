import 'package:meta/meta.dart';

import '../executable_sync_job.dart';
import '../sync_node.dart';
import 'conflict_resolver_mixin.dart';
import 'upload_job.dart';

abstract class DownloadJobBase<T extends Object> extends ExecutableSyncJob
    with ConflictResolverMixin<T> {
  final SyncNode<T> syncNode;
  final bool conflictsTriggerUpload;

  DownloadJobBase({
    required this.syncNode,
    required this.conflictsTriggerUpload,
  });

  @protected
  ExecutionResult getResult({
    required String key,
    required bool modified,
    required bool hasConflict,
  }) {
    if (conflictsTriggerUpload && hasConflict) {
      return ExecutionResult.continued(
        UploadJob(
          syncNode: syncNode,
          key: key,
          multipass: false,
        ),
      );
    }

    return modified
        ? const ExecutionResult.modified()
        : const ExecutionResult.noop();
  }
}
