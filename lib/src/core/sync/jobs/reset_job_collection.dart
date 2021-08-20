import 'dart:async';

import '../../crypto/cipher_message.dart';
import '../sync_job.dart';
import '../sync_node.dart';
import 'download_job.dart';

class ResetJobCollection<T extends Object> implements SyncJobCollection {
  final SyncNode<T> syncNode;
  final Map<String, CipherMessage> data;

  // ignore: close_sinks
  final _resultController = StreamController<SyncJobResult>();

  ResetJobCollection({
    required this.syncNode,
    required this.data,
  });

  @override
  Stream<SyncJobResult> get results => _resultController.stream;

  @override
  Stream<SyncJob> expand() {
    final jobs =
        _removeDeletedEntries.followedBy(_downloadUpdatedEntries).toList();

    Stream.fromFutures(
      jobs.map((job) => job.result),
    ).pipe(_resultController);

    return Stream.fromIterable(jobs);
  }

  Iterable<SyncJob> get _removeDeletedEntries =>
      syncNode.localStore.rawKeys.toSet().difference(data.keys.toSet()).map(
            (key) => DownloadDeleteJob(
              key: key,
              syncNode: syncNode,
              conflictsTriggerUpload: false,
            ),
          );

  Iterable<SyncJob> get _downloadUpdatedEntries => data.entries.map(
        (entry) => DownloadUpdateJob(
          key: entry.key,
          remoteCipher: entry.value,
          syncNode: syncNode,
          conflictsTriggerUpload: false,
        ),
      );
}
