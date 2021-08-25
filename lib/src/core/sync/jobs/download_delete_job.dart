import 'dart:typed_data';

import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../executable_sync_job.dart';
import '../sync_node.dart';
import 'download_job_base.dart';

class DownloadDeleteJob<T extends Object> extends DownloadJobBase<T> {
  final String key;

  DownloadDeleteJob({
    required this.key,
    required SyncNode<T> syncNode,
    required bool conflictsTriggerUpload,
  }) : super(
          syncNode: syncNode,
          conflictsTriggerUpload: conflictsTriggerUpload,
        );

  @override
  Future<ExecutionResult> executeImpl() async {
    // update locally
    late final Uint8List oldRemoteTag;
    final updatedEntry = await syncNode.localStore.update(
      key,
      (localData) {
        oldRemoteTag = localData.remoteTagOrDefault;

        if (localData == null) {
          return const UpdateAction.none();
        }

        if (!localData.locallyModified) {
          return const UpdateAction.delete();
        }

        if (!localData.remotelyModified) {
          return const UpdateAction.none();
        }

        return resolveConflict(
          key: key,
          localData: localData,
          remoteData: null,
          remoteTag: SyncObject.noRemoteDataTag,
          syncNode: syncNode,
        );
      },
    );

    return getResult(
      key: key,
      modified: oldRemoteTag != updatedEntry.remoteTagOrDefault,
      hasConflict: updatedEntry.locallyModified,
    );
  }
}