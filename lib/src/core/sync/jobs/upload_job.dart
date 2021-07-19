import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../sync_job.dart';
import '../sync_node.dart';
import 'download_job.dart';

class UploadJob<T extends Object> extends SyncJob {
  final SyncNode<T> syncNode;
  final String key;
  final bool multipass;

  UploadJob({
    required this.syncNode,
    required this.key,
    this.multipass = false,
  });

  @override
  String get storeName => syncNode.storeName;

  @override
  late final String hashedKey = syncNode.cryptoService.keyHash(
    storeName: storeName,
    key: key,
  );

  @override
  Future<bool> execute() async {
    // check if entry needs to be uploaded
    final localEntry = await syncNode.localStore.get(key);
    if (localEntry == null || !localEntry.locallyModified) {
      return false;
    }

    if (localEntry.value != null) {
      await _uploadModified(localEntry);
    } else {
      await _uploadDeleted(localEntry);
    }

    return true;
  }

  Future<void> _uploadModified(SyncObject<T> localEntry) async {
    try {
      // encrypt
      final cipher = await syncNode.cryptoService.encrypt(
        storeName: syncNode.storeName,
        store: syncNode.remoteStore,
        key: key,
        hashedKey: hashedKey,
        dataJson: syncNode.jsonConverter.dataToJson(localEntry.value!),
      );

      // upload
      final eTagReceiver = ETagReceiver();
      await syncNode.remoteStore.write(
        cipher.key,
        cipher.value,
        eTag: localEntry.eTag,
        eTagReceiver: eTagReceiver,
      );

      // finalize local entry
      final updatedEntry = await syncNode.localStore.update(key, (oldValue) {
        if (oldValue == null) {
          return UpdateAction.update(
            localEntry.updateUploaded(eTagReceiver.eTag!),
          );
        }

        if (oldValue.changeState == localEntry.changeState) {
          return UpdateAction.update(
            oldValue.updateUploaded(eTagReceiver.eTag!),
          );
        }

        return UpdateAction.update(
          oldValue.updateEtag(eTagReceiver.eTag!),
        );
      });

      // schedule another upload job if partially uploaded and multipass
      if (multipass && updatedEntry!.locallyModified) {
        // ignore: unawaited_futures
        syncNode.jobScheduler.addJob(UploadJob(
          syncNode: syncNode,
          key: key,
          multipass: multipass,
        ));
      }
    } on DbException catch (e) {
      if (e.statusCode == ApiConstants.statusCodeETagMismatch) {
        // ignore: unawaited_futures
        syncNode.jobScheduler.addJob(DownloadJob(
          syncNode: syncNode,
          hashedKey: hashedKey,
        ));
      } else {
        rethrow;
      }
    }
  }

  Future<void> _uploadDeleted(SyncObject<T> localEntry) async {
    try {
      // upload
      final eTagReceiver = ETagReceiver();
      await syncNode.remoteStore.delete(
        hashedKey,
        eTag: localEntry.eTag,
        eTagReceiver: eTagReceiver,
      );
      assert(eTagReceiver.eTag! == ApiConstants.nullETag);

      // finalize local entry
      final updatedEntry = await syncNode.localStore.update(key, (oldValue) {
        if (oldValue == null) {
          return const UpdateAction.none();
        }

        if (oldValue.changeState == localEntry.changeState) {
          return const UpdateAction.delete();
        }

        return UpdateAction.update(
          oldValue.updateEtag(eTagReceiver.eTag!),
        );
      });

      // schedule another upload job if partially uploaded and multipass
      if (multipass && (updatedEntry?.locallyModified ?? false)) {
        // ignore: unawaited_futures
        syncNode.jobScheduler.addJob(UploadJob(
          syncNode: syncNode,
          key: key,
          multipass: multipass,
        ));
      }
    } on DbException catch (e) {
      if (e.statusCode == ApiConstants.statusCodeETagMismatch) {
        // ignore: unawaited_futures
        syncNode.jobScheduler.addJob(DownloadJob(
          syncNode: syncNode,
          hashedKey: hashedKey,
        ));
      } else {
        rethrow;
      }
    }
  }
}
