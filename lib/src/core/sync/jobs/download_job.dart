import 'dart:typed_data';

import '../../crypto/cipher_message.dart';
import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../job_scheduler.dart';
import '../sync_job.dart';
import '../sync_node.dart';
import 'conflict_resolver_mixin.dart';
import 'upload_job.dart';

class DownloadJob<T extends Object> extends SyncJob
    with ConflictResolverMixin<T> {
  final SyncNode<T> syncNode;
  final bool conflictsTriggerUpload;

  @override
  final String key;
  final CipherMessage? remoteCipher;

  DownloadJob({
    required this.syncNode,
    required this.key,
    required this.remoteCipher,
    required this.conflictsTriggerUpload,
  });

  @override
  String get storeName => syncNode.storeName;

  @override
  Future<SyncJobExecutionResult> execute() async {
    final _DownloadResult downloadResult;
    if (remoteCipher != null) {
      downloadResult = await _updateLocal(remoteCipher!);
    } else {
      downloadResult = await _deleteLocal();
    }

    // trigger upload if locally changed
    if (conflictsTriggerUpload && downloadResult.hasConflict) {
      return _scheduleUpload(syncNode.jobScheduler);
    }

    return downloadResult.modified
        ? const SyncJobExecutionResult.success()
        : const SyncJobExecutionResult.noop();
  }

  Future<_DownloadResult> _updateLocal(
    CipherMessage remoteCipher,
  ) async {
    // decrypt remote data
    final plainInfo = await syncNode.dataEncryptor.decrypt(
      storeName: syncNode.storeName,
      remoteUri: syncNode.remoteStore.remoteUri(key),
      data: remoteCipher,
      extractKey: syncNode.hashKeys,
    );
    final plainData = syncNode.jsonConverter.dataFromJson(plainInfo.jsonData);

    // update locally
    late final Uint8List oldRemoteTag;
    final updatedEntry = await syncNode.localStore.update(
      key,
      (localData) {
        oldRemoteTag = localData.remoteTagOrDefault;

        if (localData == null) {
          return UpdateAction.update(SyncObject.remote(
            plainData,
            remoteCipher.remoteTag,
            plainKey: syncNode.hashKeys ? plainInfo.plainKey : null,
          ));
        }

        if (localData.remoteTag == remoteCipher.remoteTag) {
          return const UpdateAction.none();
        }

        if (!localData.locallyModified) {
          return UpdateAction.update(localData.updateRemote(
            plainData,
            remoteCipher.remoteTag,
          ));
        }

        return resolveConflict(
          key: key,
          localData: localData,
          remoteData: plainData,
          remoteTag: remoteCipher.remoteTag,
          syncNode: syncNode,
        );
      },
    );

    return _DownloadResult(
      modified: oldRemoteTag != updatedEntry.remoteTagOrDefault,
      hasConflict: updatedEntry.locallyModified,
    );
  }

  Future<_DownloadResult> _deleteLocal() async {
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

    return _DownloadResult(
      modified: oldRemoteTag != updatedEntry.remoteTagOrDefault,
      hasConflict: updatedEntry.locallyModified,
    );
  }

  SyncJobExecutionResult _scheduleUpload(JobScheduler scheduler) {
    final uploadJob = UploadJob(
      syncNode: syncNode,
      key: key,
      multipass: false,
    );
    // ignore: unawaited_futures
    syncNode.jobScheduler.addJob(uploadJob);
    return SyncJobExecutionResult.next(uploadJob);
  }
}

class _DownloadResult {
  final bool modified;
  final bool hasConflict;

  _DownloadResult({
    required this.modified,
    required this.hasConflict,
  });
}
