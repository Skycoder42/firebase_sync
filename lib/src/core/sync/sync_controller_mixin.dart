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
  Filter? _syncFilter;
  bool _autoRenew = true;
  StreamCancallationToken? _uploadToken;
  StreamCancallationToken? _downloadToken;

  @override
  SyncMode get syncMode => _syncMode;

  @override
  Filter? get syncFilter => _syncFilter;

  @override
  bool get autoRenew => _autoRenew;

  @override
  Future<void> setSyncFilter(Filter? filter) async {
    _syncFilter = filter;
    if (_downloadToken != null) {
      await _stopDownsync();
      await _startDownsync();
    }
  }

  @override
  Future<void> setSyncMode(SyncMode syncMode) async {
    if (syncMode == _syncMode) {
      return;
    }

    try {
      switch (syncMode) {
        case SyncMode.none:
          await Future.wait([
            _stopDownsync(),
            _stopUpsync(),
          ]);
          break;
        case SyncMode.upload:
          await Future.wait([
            _stopDownsync(),
            _startUpsync(),
          ]);
          break;
        case SyncMode.download:
          await Future.wait([
            _stopUpsync(),
            _startDownsync(),
          ]);
          break;
        case SyncMode.sync:
          await Future.wait([
            _startUpsync(),
            _startDownsync(),
          ]);
          break;
      }
      _syncMode = syncMode;
    } catch (e) {
      _syncMode = SyncMode.none;
      await Future.wait([
        _stopDownsync(),
        _stopUpsync(),
      ]);
      rethrow;
    }
  }

  @override
  Future<void> setAutoRenew(bool autoRenew) async {
    if (autoRenew == _autoRenew) {
      return;
    }

    _autoRenew = autoRenew;
    if (_downloadToken != null) {
      await _stopDownsync();
      await _startDownsync();
    }
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

  @protected
  Future<void> destroyNode() async {
    await setSyncMode(SyncMode.none);
    await syncNode.jobScheduler.purgeJobs(syncNode.storeName);
    await syncNode.remoteStore.destroy();
  }

  Future<void> _startUpsync() {
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
      '${syncNode.storeName}:upload',
    );
    return Future.value();
  }

  Future<void> _stopUpsync() {
    final cancelFuture = _uploadToken?.cancel();
    _uploadToken = null;
    return cancelFuture ?? Future.value();
  }

  Future<void> _startDownsync() async {
    if (_downloadToken == null) {
      final Stream<StoreEvent<CipherMessage>> stream;
      if (autoRenew) {
        stream = AutoRenewStream.fromStream(
          await _createDownstream(),
          _createDownstream,
        );
      } else {
        stream = await _createDownstream();
      }

      _downloadToken ??= syncNode.jobScheduler.addJobStream(
        stream.expand(
          (event) => event.when(
            reset: (data) => syncNode.localStore.rawKeys
                .where((key) => !data.keys.contains(key))
                .map(
                  (key) => DownloadJob(
                    syncNode: syncNode,
                    key: key,
                    remoteCipher: null,
                    conflictsTriggerUpload: false,
                  ),
                )
                .followedBy(
                  data.entries.map(
                    (entry) => DownloadJob(
                      syncNode: syncNode,
                      key: entry.key,
                      remoteCipher: entry.value,
                      conflictsTriggerUpload: false,
                    ),
                  ),
                ),
            put: (key, value) => [
              DownloadJob(
                syncNode: syncNode,
                key: key,
                remoteCipher: value,
                conflictsTriggerUpload: false,
              )
            ],
            delete: (key) => [
              DownloadJob(
                syncNode: syncNode,
                key: key,
                remoteCipher: null,
                conflictsTriggerUpload: false,
              )
            ],
            patch: (_, __) => const [],
            invalidPath: (_) => const [],
          ),
        ),
        '${syncNode.storeName}:download',
      );
    }
  }

  Future<Stream<StoreEvent<CipherMessage>>> _createDownstream() =>
      _syncFilter != null
          ? syncNode.remoteStore.streamQuery(_syncFilter!)
          : syncNode.remoteStore.streamAll();

  Future<void> _stopDownsync() {
    final cancelFuture = _downloadToken?.cancel();
    _downloadToken = null;
    return cancelFuture ?? Future.value();
  }
}

extension _SyncJobResultListX on Iterable<SyncJobResult> {
  int successCount() => fold<int>(
        0,
        (previousValue, result) =>
            result == SyncJobResult.success ? previousValue + 1 : previousValue,
      );
}
