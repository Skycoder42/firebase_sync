import 'package:meta/meta.dart';

import '../../crypto/cipher_message.dart';
import '../executable_sync_job.dart';
import '../expandable_sync_job.dart';
import '../sync_node.dart';
import 'download_delete_job.dart';
import 'download_update_job.dart';

mixin ResetLocalMixin<T extends Object> on ExpandableSyncJob {
  @visibleForOverriding
  SyncNode<T> get syncNode;

  Iterable<ExecutableSyncJob> generateJobs({
    required Map<String, CipherMessage> data,
    required bool conflictsTriggerUpload,
  }) =>
      _removeDeletedEntries(
        data: data,
        conflictsTriggerUpload: conflictsTriggerUpload,
      ).followedBy(_downloadUpdatedEntries(
        data: data,
        conflictsTriggerUpload: conflictsTriggerUpload,
      ));

  Iterable<ExecutableSyncJob> _removeDeletedEntries({
    required Map<String, CipherMessage> data,
    required bool conflictsTriggerUpload,
  }) =>
      syncNode.localStore.rawKeys.toSet().difference(data.keys.toSet()).map(
            (key) => DownloadDeleteJob(
              key: key,
              syncNode: syncNode,
              conflictsTriggerUpload: conflictsTriggerUpload,
            ),
          );

  Iterable<ExecutableSyncJob> _downloadUpdatedEntries({
    required Map<String, CipherMessage> data,
    required bool conflictsTriggerUpload,
  }) =>
      data.entries.map(
        (entry) => DownloadUpdateJob(
          key: entry.key,
          remoteCipher: entry.value,
          syncNode: syncNode,
          conflictsTriggerUpload: conflictsTriggerUpload,
        ),
      );
}
