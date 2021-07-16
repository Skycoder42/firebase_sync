import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/sync_object.dart';
import 'package:firebase_sync/src/core/store/update_action.dart';
import 'package:firebase_sync/src/core/cipher_message.dart';
import 'package:firebase_sync/src/core/crypto/crypto_service.dart';
import 'package:firebase_sync/src/sync/job_scheduler.dart';

import '../core/store.dart';
import 'sync_job.dart';

class UploadJob<T extends Object> extends SyncJob {
  final SyncObjectStore<T> localStore;
  final JsonConverter<T> localConverter;
  final FirebaseStore<CipherMessage> remoteStore;
  final CryptoService cryptoService;

  final String key;

  UploadJob({
    required this.localStore,
    required this.localConverter,
    required this.remoteStore,
    required this.cryptoService,
    required this.key,
  });

  @override
  late final String hashedKey = cryptoService.keyHash(key);

  @override
  Future<void> execute(JobScheduler scheduler) async {
    // prepare the local entry for uploading
    final localEntry = await localStore.get(key);
    if (localEntry == null || !localEntry.locallyModified) {
      return;
    }

    if (localEntry.value != null) {
      await _uploadModified(scheduler, localEntry);
    }
  }

  Future<void> _uploadModified(
    JobScheduler scheduler,
    SyncObject<T> localEntry,
  ) async {
    try {
      // encrypt
      final cipher = cryptoService.encrypt(
        store: remoteStore,
        key: key,
        hashedKey: hashedKey,
        dataJson: localConverter.dataToJson(localEntry.value!),
      );

      // upload
      final eTagReceiver = ETagReceiver();
      await remoteStore.write(
        cipher.key,
        cipher.value,
        eTag: localEntry.eTag,
        eTagReceiver: eTagReceiver,
      );

      // finalize local entry
      await localStore.update(key, (oldValue) {
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
          oldValue.copyWith(eTag: eTagReceiver.eTag!),
        );
      });
    } catch (e) {
      await localStore.update(key, (oldValue) {
        if (oldValue != null && oldValue.changeState == ChangeState.uploading) {
          return UpdateAction.update(
            oldValue.copyWith(changeState: ChangeState.modified),
          );
        } else {
          return const UpdateAction.none();
        }
      });

      if ((e is DbException) &&
          e.statusCode == ApiConstants.statusCodeETagMismatch) {
        // TODO add download job
        throw UnimplementedError();
      } else {
        rethrow;
      }
    }
  }
}
