import 'dart:async';

import '../../crypto/cipher_message.dart';
import '../executable_sync_job.dart';
import '../expandable_sync_job.dart';
import '../sync_node.dart';
import 'download_job.dart';

class ResetJob<T extends Object> extends ExpandableSyncJob {
  final SyncNode<T> syncNode;
  final Map<String, CipherMessage> data;

  ResetJob({
    required this.syncNode,
    required this.data,
  });

  @override
  Stream<ExecutableSyncJob> expandImpl() => Stream.fromIterable(
        _removeDeletedEntries.followedBy(_downloadUpdatedEntries),
      );

  Iterable<ExecutableSyncJob> get _removeDeletedEntries =>
      syncNode.localStore.rawKeys.toSet().difference(data.keys.toSet()).map(
            (key) => DownloadDeleteJob(
              key: key,
              syncNode: syncNode,
              conflictsTriggerUpload: false,
            ),
          );

  Iterable<ExecutableSyncJob> get _downloadUpdatedEntries => data.entries.map(
        (entry) => DownloadUpdateJob(
          key: entry.key,
          remoteCipher: entry.value,
          syncNode: syncNode,
          conflictsTriggerUpload: false,
        ),
      );
}
