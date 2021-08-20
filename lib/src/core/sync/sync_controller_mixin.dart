import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../crypto/cipher_message.dart';
import '../store/sync_object.dart';
import 'download_job_transformer.dart';
import 'jobs/download_job.dart';
import 'jobs/reset_job_collection.dart';
import 'jobs/upload_job.dart';
import 'sync_controller.dart';
import 'sync_job.dart';
import 'sync_mode.dart';
import 'sync_node.dart';
import 'upload_job_transformer.dart';

mixin SyncControllerMixin<T extends Object> implements SyncController<T> {
  @visibleForOverriding
  SyncNode<T> get syncNode;

  SyncMode _syncMode = SyncMode.none;
  Filter? _syncFilter;
  bool _autoRenew = true;
  StreamSubscription<void>? _uploadSub;
  StreamSubscription<void>? _downloadSub;

  @override
  SyncMode get syncMode => _syncMode;

  @override
  Filter? get syncFilter => _syncFilter;

  @override
  bool get autoRenew => _autoRenew;

  @override
  Future<void> setSyncFilter(Filter? filter) async {
    _syncFilter = filter;
    if (_downloadSub != null) {
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
    if (_downloadSub != null) {
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

    return syncNode.syncJobExecutor
        .addCollection(
          ResetJobCollection(
            syncNode: syncNode,
            data: entries,
          ),
        )
        .successCount();
  }

  @override
  Future<int> upload({bool multipass = true}) async {
    final entries = await syncNode.localStore.listEntries();
    return syncNode.syncJobExecutor
        .addAll(
          entries.entries
              .where((entry) => entry.value.locallyModified)
              .map((entry) => UploadJob(
                    syncNode: syncNode,
                    key: entry.key,
                    multipass: false,
                  )),
        )
        .successCount();
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
    _uploadSub ??= syncNode.syncJobExecutor.addStream(
      syncNode.localStore.watch().asUploadJobs(syncNode),
    );
    return Future.value();
  }

  Future<void> _stopUpsync() {
    final cancelFuture = _uploadSub?.cancel();
    _uploadSub = null;
    return cancelFuture ?? Future.value();
  }

  Future<void> _startDownsync() async {
    if (_downloadSub == null) {
      final Stream<StoreEvent<CipherMessage>> stream;
      if (autoRenew) {
        stream = AutoRenewStream.fromStream(
          await _createDownstream(),
          _createDownstream,
        );
      } else {
        stream = await _createDownstream();
      }

      _downloadSub ??= syncNode.syncJobExecutor
          .addCollectionStream(stream.asDownloadJobs(syncNode));
    }
  }

  Future<Stream<StoreEvent<CipherMessage>>> _createDownstream() =>
      _syncFilter != null
          ? syncNode.remoteStore.streamQuery(_syncFilter!)
          : syncNode.remoteStore.streamAll();

  Future<void> _stopDownsync() {
    final cancelFuture = _downloadSub?.cancel();
    _downloadSub = null;
    return cancelFuture ?? Future.value();
  }
}

extension _SyncJobResultListX on Stream<SyncJobResult> {
  Future<int> successCount() => fold<int>(
        0,
        (previousValue, result) =>
            result == SyncJobResult.success ? previousValue + 1 : previousValue,
      );
}
