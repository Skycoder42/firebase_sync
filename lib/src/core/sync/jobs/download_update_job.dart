import 'dart:typed_data';

import '../../crypto/cipher_message.dart';
import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../executable_sync_job.dart';
import '../sync_node.dart';
import 'download_job_base.dart';

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
  Future<ExecutionResult> executeImpl() async {
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
