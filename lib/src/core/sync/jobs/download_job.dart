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
  final String hashedKey;

  DownloadJob({
    required this.syncNode,
    required this.hashedKey,
    this.conflictsTriggerUpload = false,
  });

  @override
  String get storeName => syncNode.storeName;

  @override
  Future<bool> execute() async {
    // download remote entry
    final eTagReceiver = ETagReceiver();
    final remoteCipher = await syncNode.remoteStore.read(
      hashedKey,
      eTagReceiver: eTagReceiver,
    );

    if (remoteCipher != null) {
      await _updateLocal(remoteCipher, eTagReceiver.eTag!);
    } else {
      await _deleteLocal();
    }

    return true;
  }

  Future<void> _updateLocal(CipherMessage remoteCipher, String eTag) async {
    // decrypt remote data
    final plainInfo = await syncNode.cryptoService.decrypt(
      storeName: syncNode.storeName,
      store: syncNode.remoteStore,
      hashedKey: hashedKey,
      data: remoteCipher,
    );
    final plainData = syncNode.jsonConverter.dataFromJson(plainInfo.value);

    // update locally
    final updatedEntry = await syncNode.localStore.update(
      plainInfo.key,
      (localData) {
        if (localData == null) {
          return UpdateAction.update(SyncObject.remote(plainData, eTag));
        }

        if (!localData.locallyModified) {
          return UpdateAction.update(localData.updateRemote(plainData, eTag));
        }

        return syncNode.conflictResolver
            .resolve(
              plainInfo.key,
              local: localData.value,
              remote: plainData,
            )
            .when(
              local: () => UpdateAction.update(
                localData.updateEtag(eTag),
              ),
              remote: () => UpdateAction.update(
                SyncObject.remote(plainData, eTag),
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
        key: plainInfo.key,
        multipass: false,
      ));
    }
  }

  Future<void> _deleteLocal() {
    // TODO its impossible with hashed keys
    throw UnimplementedError();
  }
}
