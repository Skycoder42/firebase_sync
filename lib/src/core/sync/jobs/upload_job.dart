import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../../crypto/cipher_message.dart';
import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../job_scheduler.dart';
import '../sync_job.dart';
import '../sync_node.dart';
import 'conflict_resolver_mixin.dart';

class UploadJob<T extends Object> extends SyncJob
    with ConflictResolverMixin<T> {
  final SyncNode<T> syncNode;
  final bool multipass;

  UploadJob({
    required this.syncNode,
    required this.key,
    required this.multipass,
  });

  @override
  String get storeName => syncNode.storeName;

  @override
  final String key;

  @override
  Future<SyncJobExecutionResult> execute() async {
    // check if entry needs to be uploaded
    var localEntry = await syncNode.localStore.get(key);
    if (!localEntry.locallyModified) {
      return const SyncJobExecutionResult.noop();
    }

    // begin transaction
    final transaction = await syncNode.remoteStore.transaction(key);

    // check for and resolve conflicts
    final remoteTag =
        transaction.value?.remoteTag ?? SyncObject.noRemoteDataTag;
    if (localEntry!.remoteTag != remoteTag) {
      localEntry = await _resolveConflict(transaction);
      if (!localEntry.locallyModified) {
        return const SyncJobExecutionResult.success();
      }
    }

    // start upload
    try {
      final bool stillModified;
      if (localEntry!.value != null) {
        stillModified = await _uploadModified(localEntry, transaction);
      } else {
        stillModified = await _uploadDeleted(localEntry, transaction);
      }

      // schedule another upload job if partially uploaded and multipass
      if (multipass && stillModified) {
        return _reschedule(syncNode.jobScheduler);
      }

      return const SyncJobExecutionResult.success();
    } on TransactionFailedException {
      // reschedule "this" job to try again -> will lead to a conflict resoltion
      return _reschedule(syncNode.jobScheduler);
    }
  }

  Future<bool> _uploadModified(
    SyncObject<T> localEntry,
    FirebaseTransaction<CipherMessage> transaction,
  ) async {
    // encrypt
    final cipher = await syncNode.dataEncryptor.encrypt(
      remoteUri: syncNode.remoteStore.remoteUri(key),
      dataJson: syncNode.jsonConverter.dataToJson(localEntry.value!),
    );

    // upload
    await transaction.commitUpdate(cipher);

    // finalize local entry
    final updatedEntry = await syncNode.localStore.update(key, (oldValue) {
      if (oldValue == null) {
        return UpdateAction.update(
          localEntry.updateUploaded(cipher.remoteTag),
        );
      }

      if (oldValue.changeState == localEntry.changeState) {
        return UpdateAction.update(
          oldValue.updateUploaded(cipher.remoteTag),
        );
      }

      return UpdateAction.update(
        oldValue.updateRemoteTag(cipher.remoteTag),
      );
    });

    return updatedEntry.locallyModified;
  }

  Future<bool> _uploadDeleted(
    SyncObject<T> localEntry,
    FirebaseTransaction<CipherMessage> transaction,
  ) async {
    // delete remotely
    await transaction.commitDelete();

    // finalize local entry
    final updatedEntry = await syncNode.localStore.update(key, (oldValue) {
      if (oldValue == null) {
        return const UpdateAction.none();
      }

      if (oldValue.changeState == localEntry.changeState) {
        return const UpdateAction.delete();
      }

      return UpdateAction.update(
        oldValue.updateRemoteTag(SyncObject.noRemoteDataTag),
      );
    });

    return updatedEntry.locallyModified;
  }

  Future<SyncObject<T>?> _resolveConflict(
    FirebaseTransaction<CipherMessage> transaction,
  ) async {
    // decrypt remote data, if not null
    final T? remoteData;
    if (transaction.value != null) {
      final dynamic jsonData = await syncNode.dataEncryptor.decrypt(
        remoteUri: syncNode.remoteStore.remoteUri(key),
        data: transaction.value!,
      );
      remoteData = syncNode.jsonConverter.dataFromJson(jsonData);
    } else {
      remoteData = null;
    }

    return syncNode.localStore.update(
      key,
      (oldValue) {
        if (oldValue == null) {
          return const UpdateAction.none();
        }

        return resolveConflict(
          key: key,
          localData: oldValue,
          remoteData: remoteData,
          remoteTag: transaction.value?.remoteTag ?? SyncObject.noRemoteDataTag,
          syncNode: syncNode,
        );
      },
    );
  }

  SyncJobExecutionResult _reschedule(JobScheduler scheduler) {
    final job = UploadJob(
      syncNode: syncNode,
      key: key,
      multipass: multipass,
    );
    scheduler.addJob(job);
    return SyncJobExecutionResult.next(job);
  }
}
