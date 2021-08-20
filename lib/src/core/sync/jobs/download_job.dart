import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../crypto/cipher_message.dart';
import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../sync_job.dart';
import '../sync_node.dart';
import 'conflict_resolver_mixin.dart';
import 'upload_job.dart';

@visibleForTesting
abstract class DownloadJobBase<T extends Object> extends SyncJob
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

class DownloadUpdateJob<T extends Object> extends DownloadJobBase<T> {
  final String key;
  final CipherMessage remoteCipher;

  DownloadUpdateJob({
    required this.key,
    required this.remoteCipher,
    required SyncNode<T> syncNode,
    required bool conflictsTriggerUpload,
  }) : super(
          syncNode: syncNode,
          conflictsTriggerUpload: conflictsTriggerUpload,
        );

  @override
  Future<ExecutionResult> execute() async {
    // decrypt remote data
    final dynamic plainJson = await syncNode.dataEncryptor.decrypt(
      remoteUri: syncNode.remoteStore.remoteUri(key),
      data: remoteCipher,
    );
    final plainData = syncNode.jsonConverter.dataFromJson(plainJson);

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

    return getResult(
      key: key,
      modified: oldRemoteTag != updatedEntry.remoteTagOrDefault,
      hasConflict: updatedEntry.locallyModified,
    );
  }
}

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
  Future<ExecutionResult> execute() async {
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
