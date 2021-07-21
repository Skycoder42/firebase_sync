import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../../crypto/cipher_message.dart';
import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../sync_job.dart';
import '../sync_node.dart';
import 'upload_job.dart';

class DownloadJob<T extends Object> extends SyncJob {
  final SyncNode<T> syncNode;
  final bool conflictsTriggerUpload;

  @override
  final String key;

  DownloadJob({
    required this.syncNode,
    required this.key,
    this.conflictsTriggerUpload = false,
  });

  @override
  String get storeName => syncNode.storeName;

  @override
  Future<bool> execute() async {
    // download remote entry
    final eTagReceiver = ETagReceiver();
    final remoteCipher = await syncNode.remoteStore.read(
      key,
      eTagReceiver: eTagReceiver,
    );

    if (remoteCipher != null) {
      await _updateLocal(remoteCipher, eTagReceiver.eTag!);
    } else {
      assert(eTagReceiver.eTag! == ApiConstants.nullETag);
      await _deleteLocal();
    }

    return true;
  }

  Future<void> _updateLocal(CipherMessage remoteCipher, String eTag) async {
    // decrypt remote data
    final plainInfo = await syncNode.dataEncryptor.decrypt(
      storeName: syncNode.storeName,
      store: syncNode.remoteStore,
      key: key,
      data: remoteCipher,
      extractKey: syncNode.hashKeys,
    );
    final plainData = syncNode.jsonConverter.dataFromJson(plainInfo.jsonData);

    // update locally
    final updatedEntry = await syncNode.localStore.update(
      key,
      (localData) {
        if (localData == null) {
          return UpdateAction.update(SyncObject.remote(
            plainData,
            eTag,
            plainKey: syncNode.hashKeys ? plainInfo.plainKey : null,
          ));
        }

        if (!localData.locallyModified) {
          return UpdateAction.update(localData.updateRemote(plainData, eTag));
        }

        return syncNode.conflictResolver
            .resolve(
              syncNode.hashKeys ? localData.plainKey! : key,
              local: localData.value,
              remote: plainData,
            )
            .when(
              local: () => UpdateAction.update(
                localData.updateEtag(eTag),
              ),
              remote: () => UpdateAction.update(
                SyncObject.remote(
                  plainData,
                  eTag,
                  plainKey: syncNode.hashKeys ? plainInfo.plainKey : null,
                ),
              ),
              delete: () => const UpdateAction.delete(),
              update: (updated) => UpdateAction.update(
                localData.updateLocal(updated, eTag: eTag),
              ),
            );
      },
    );

    // trigger upload if locally changed
    if (conflictsTriggerUpload && (updatedEntry?.locallyModified ?? false)) {
      // ignore: unawaited_futures
      syncNode.jobScheduler.addJob(UploadJob(
        syncNode: syncNode,
        key: key,
        multipass: false,
      ));
    }
  }

  Future<void> _deleteLocal() async {
    // update locally
    final updatedEntry = await syncNode.localStore.update(
      key,
      (localData) {
        if (localData == null) {
          return const UpdateAction.none();
        }

        if (!localData.locallyModified) {
          return const UpdateAction.delete();
          // TODO delete does not trigger stream events correctly
        }

        return syncNode.conflictResolver
            .resolve(
              syncNode.hashKeys ? localData.plainKey! : key,
              local: localData.value,
              remote: null,
            )
            .when(
              local: () => UpdateAction.update(
                localData.updateEtag(ApiConstants.nullETag),
              ),
              remote: () => const UpdateAction.delete(),
              delete: () => const UpdateAction.delete(),
              update: (updated) => UpdateAction.update(
                localData.updateLocal(updated, eTag: ApiConstants.nullETag),
              ),
            );
      },
    );

    // trigger upload if locally changed
    if (conflictsTriggerUpload && (updatedEntry?.locallyModified ?? false)) {
      // ignore: unawaited_futures
      syncNode.jobScheduler.addJob(UploadJob(
        syncNode: syncNode,
        key: key,
        multipass: false,
      ));
    }
  }
}
