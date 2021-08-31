import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../crypto/cipher_message.dart';
import 'jobs/download_all_job.dart';
import 'jobs/upload_all_job.dart';
import 'sync_controller.dart';
import 'sync_error.dart';
import 'sync_job.dart';
import 'sync_mode.dart';
import 'sync_node.dart';
import 'transformers/download_job_transformer.dart';
import 'transformers/upload_job_transformer.dart';

mixin SyncControllerMixin<T extends Object> implements SyncController<T> {
  @visibleForOverriding
  SyncNode<T> get syncNode;

  Filter? _syncFilter;
  bool _autoRenew = true;
  StreamSubscription<void>? _uploadSub;
  StreamSubscription<void>? _downloadSub;

  @override
  Stream<SyncError> get syncErrors => syncNode.syncJobExecutor.syncErrors;

  @override
  SyncMode get syncMode {
    if (_uploadSub != null && _downloadSub != null) {
      return SyncMode.sync;
    } else if (_uploadSub != null) {
      return SyncMode.upload;
    } else if (_downloadSub != null) {
      return SyncMode.download;
    } else {
      return SyncMode.none;
    }
  }

  @override
  Filter? get syncFilter => _syncFilter;

  @override
  bool get autoRenew => _autoRenew;

  @override
  set syncFilter(Filter? filter) {
    _syncFilter = filter;
    _restartDownsyncIfRunning();
  }

  @override
  set autoRenew(bool autoRenew) {
    if (autoRenew == _autoRenew) {
      return;
    }

    _autoRenew = autoRenew;
    _restartDownsyncIfRunning();
  }

  @override
  set syncMode(SyncMode syncMode) {
    if (syncMode == this.syncMode) {
      return;
    }

    try {
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
          _startDownsync();
          break;
        case SyncMode.sync:
          _startUpsync();
          _startDownsync();
          break;
      }
    } catch (e) {
      _stopDownsync();
      _stopUpsync();
      rethrow;
    }
  }

  @override
  Future<SyncJobResult> download({
    Filter? filter,
    bool conflictsTriggerUpload = false,
  }) =>
      syncNode.syncJobExecutor.add(
        DownloadAllJob(
          syncNode: syncNode,
          filter: filter,
          conflictsTriggerUpload: conflictsTriggerUpload,
        ),
      );

  @override
  Future<SyncJobResult> upload({bool multipass = true}) =>
      syncNode.syncJobExecutor.add(
        UploadAllJob(
          syncNode: syncNode,
          multipass: multipass,
        ),
      );

  @override
  Future<SyncJobResult> reload({
    Filter? filter,
    bool multipass = true,
  }) =>
      Stream.fromFutures([
        download(filter: filter),
        upload(multipass: multipass),
      ]).reduce(
        (previous, element) => previous.combine(element),
      );

  @protected
  @nonVirtual
  Future<void> destroySync() async {
    await closeSync();
    await syncNode.remoteStore.destroy();
  }

  @protected
  @nonVirtual
  Future<void> closeSync() async {
    await Future.wait(
      [_downloadSub?.cancel(), _uploadSub?.cancel()]
          .where((future) => future != null)
          .cast(),
    );
    await syncNode.close();
  }

  void _startUpsync() {
    _uploadSub ??= syncNode.syncJobExecutor.addStream(
      syncNode.localStore.watch().asUploadJobs(syncNode),
    );
  }

  void _stopUpsync() {
    _uploadSub?.cancel().catchError(syncNode.syncJobExecutor.addError);
    _uploadSub = null;
  }

  void _startDownsync() {
    if (_downloadSub == null) {
      final Stream<StoreEvent<CipherMessage>> stream;
      if (autoRenew) {
        stream = AutoRenewStream(
          _createDownstream,
        );
      } else {
        stream = Stream.fromFuture(_createDownstream())
            .asyncExpand((stream) => stream);
      }

      _downloadSub ??= syncNode.syncJobExecutor.addStream(
        stream.asDownloadJobs(syncNode),
      );
    }
  }

  void _stopDownsync() {
    _downloadSub?.cancel().catchError(syncNode.syncJobExecutor.addError);
    _downloadSub = null;
  }

  void _restartDownsyncIfRunning() {
    if (_downloadSub != null) {
      _stopDownsync();
      _startDownsync();
    }
  }

  Future<Stream<StoreEvent<CipherMessage>>> _createDownstream() =>
      _syncFilter != null
          ? syncNode.remoteStore.streamQuery(_syncFilter!)
          : syncNode.remoteStore.streamAll();
}
