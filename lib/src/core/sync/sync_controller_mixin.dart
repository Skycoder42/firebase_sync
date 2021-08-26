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

  SyncMode _syncMode = SyncMode.none;
  Filter? _syncFilter;
  bool _autoRenew = true;
  StreamSubscription<void>? _uploadSub;
  StreamSubscription<void>? _downloadSub;

  @override
  Stream<SyncError> get syncErrors => syncNode.syncJobExecutor.syncErrors;

  @override
  SyncMode get syncMode => _syncMode;

  @override
  Filter? get syncFilter => _syncFilter;

  @override
  bool get autoRenew => _autoRenew;

  @override
  Future<void> setSyncFilter(Filter? filter) async {
    _syncFilter = filter;
    await _restartDownsyncIfRunning();
  }

  @override
  Future<void> setAutoRenew(bool autoRenew) async {
    if (autoRenew == _autoRenew) {
      return;
    }

    _autoRenew = autoRenew;
    await _restartDownsyncIfRunning();
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
        // TODO does not work that way
        download(filter: filter),
        upload(multipass: multipass),
      ]).reduceToMostImportant();

  @protected
  Future<void> destroyRemote() async {
    assert(
      _syncMode == SyncMode.none,
      'Synchronisation must be stopped before destroying a remote',
    );
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

      _downloadSub ??= syncNode.syncJobExecutor.addStream(
        stream.asDownloadJobs(syncNode),
      );
    }
  }

  Future<void> _stopDownsync() {
    final cancelFuture = _downloadSub?.cancel();
    _downloadSub = null;
    return cancelFuture ?? Future.value();
  }

  Future<void> _restartDownsyncIfRunning() async {
    if (_downloadSub != null) {
      await _stopDownsync();
      await _startDownsync();
    }
  }

  Future<Stream<StoreEvent<CipherMessage>>> _createDownstream() =>
      _syncFilter != null
          ? syncNode.remoteStore.streamQuery(_syncFilter!)
          : syncNode.remoteStore.streamAll();
}

extension _SyncJobResultListX on Stream<SyncJobResult> {
  Future<SyncJobResult> reduceToMostImportant() => reduce(
        (previous, element) =>
            element.index > previous.index ? element : previous,
      );
}
