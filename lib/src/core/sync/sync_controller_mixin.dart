import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../crypto/cipher_message.dart';
import '../store/sync_object.dart';
import 'job_scheduler.dart';
import 'jobs/download_job.dart';
import 'jobs/upload_job.dart';
import 'sync_controller.dart';
import 'sync_job.dart';
import 'sync_mode.dart';
import 'sync_node.dart';

mixin SyncControllerMixin<T extends Object> implements SyncController<T> {
  @visibleForOverriding
  SyncNode<T> get syncNode;

  SyncMode _syncMode = SyncMode.none;
  StreamCancallationToken? _uploadToken;
  StreamCancallationToken? _downloadToken;

  @override
  SyncMode get syncMode => _syncMode;

  @override
  Future<void> setSyncMode(SyncMode syncMode) async {
    if (syncMode == _syncMode) {
      return;
    }

    switch (syncMode) {
      case SyncMode.none:
        _stopDownsync();
        _stopUpsync();
        break;
      case SyncMode.upload:
        _stopDownsync();
        _startUpsync();
        break;
      case SyncMode.download:
        _stopUpsync();
        await _startDownsync();
        break;
      case SyncMode.sync:
        _startUpsync();
        await _startDownsync();
        break;
    }

    _syncMode = syncMode;
  }

  @override
  Future<int> download({
    Filter? filter,
    bool conflictsTriggerUpload = false,
  }) async {
    final entries = filter != null
        ? await syncNode.remoteStore.query(filter)
        : await syncNode.remoteStore.all();

    final jobResults = await syncNode.jobScheduler.addJobs(
      entries.entries
          .map(
            (entry) => DownloadJob(
              syncNode: syncNode,
              key: entry.key,
              remoteCipher: entry.value,
              conflictsTriggerUpload: conflictsTriggerUpload,
            ),
          )
          .toList(),
    );

    return jobResults.successCount();
  }

  @override
  Future<int> upload({bool multipass = true}) async {
    final entries = await syncNode.localStore.listEntries();
    final jobResults = await syncNode.jobScheduler.addJobs(
      entries.entries
          .where((entry) => entry.value.locallyModified)
          .map((entry) => UploadJob(
                syncNode: syncNode,
                key: entry.key,
                multipass: false,
              ))
          .toList(),
    );

    return jobResults.successCount();
  }

  @override
  Future<int> reload({
    Filter? filter,
    bool multipass = true,
  }) async {
    final downloadCnt = await download(filter: filter);
    final uploadCnt = await upload(multipass: multipass);
    return downloadCnt + uploadCnt;
  }

  @override
  Future<void> destroy() => syncNode.remoteStore.destroy();

  void _startUpsync() {
    _uploadToken ??= syncNode.jobScheduler.addJobStream(
      syncNode.localStore
          .watch()
          .where((event) => event.value.locallyModified)
          .map(
            (event) => UploadJob(
              syncNode: syncNode,
              key: event.key,
              multipass: false,
            ),
          ),
    );
  }

  void _stopUpsync() {
    _uploadToken?.cancel();
    _uploadToken = null;
  }

  Future<void> _startDownsync() async {
    if (_downloadToken == null) {
      // TODO query support
      final stream = await syncNode.remoteStore.streamAll();
      _downloadToken ??= syncNode.jobScheduler.addJobStream(
        stream
            .map(
              (event) => event.when<Iterable<MapEntry<String, CipherMessage?>>>(
                reset: (data) => data.entries,
                put: (key, value) => [MapEntry(key, value)],
                delete: (key) => [MapEntry(key, null)],
                patch: (_, __) => const [],
                invalidPath: (_) => const [],
              ),
            )
            .expand((entries) => entries)
            .map(
              (entry) => DownloadJob(
                syncNode: syncNode,
                key: entry.key,
                remoteCipher: entry.value,
                conflictsTriggerUpload: false,
              ),
            ),
      );
    }
  }

  void _stopDownsync() {
    _downloadToken?.cancel();
    _downloadToken = null;
  }
}

extension _SyncJobResultListX on Iterable<SyncJobResult> {
  int successCount() => fold<int>(
        0,
        (previousValue, result) =>
            result == SyncJobResult.success ? previousValue + 1 : previousValue,
      );
}
