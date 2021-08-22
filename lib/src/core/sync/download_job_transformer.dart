import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../crypto/cipher_message.dart';
import 'jobs/download_job.dart';
import 'jobs/reset_job.dart';
import 'sync_job.dart';
import 'sync_node.dart';

extension DownloadJobTransformerX on Stream<StoreEvent<CipherMessage>> {
  Stream<SyncJob> asDownloadJobs<T extends Object>(
    SyncNode<T> syncNode,
  ) =>
      transform(DownloadJobTransformer<T>(syncNode));
}

@visibleForTesting
class DownloadJobTransformerSink<T extends Object>
    implements EventSink<StoreEvent<CipherMessage>> {
  final SyncNode<T> syncNode;
  final EventSink<SyncJob> sink;

  DownloadJobTransformerSink({
    required this.syncNode,
    required this.sink,
  });

  @override
  void add(StoreEvent<CipherMessage> event) {
    event.when(
      reset: _reset,
      put: _put,
      delete: _delete,
      patch: (_, __) {},
      invalidPath: (_) {},
    );
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      sink.addError(error, stackTrace);

  @override
  void close() => sink.close();

  void _reset(Map<String, CipherMessage> data) {
    sink.add(
      ResetJob(
        syncNode: syncNode,
        data: data,
      ),
    );
  }

  void _put(String key, CipherMessage value) {
    sink.add(
      DownloadUpdateJob(
        syncNode: syncNode,
        key: key,
        remoteCipher: value,
        conflictsTriggerUpload: false,
      ),
    );
  }

  void _delete(String key) {
    sink.add(
      DownloadDeleteJob(
        syncNode: syncNode,
        key: key,
        conflictsTriggerUpload: false,
      ),
    );
  }
}

@visibleForTesting
class DownloadJobTransformer<T extends Object>
    implements StreamTransformer<StoreEvent<CipherMessage>, SyncJob> {
  final SyncNode<T> syncNode;

  const DownloadJobTransformer(this.syncNode);

  @override
  Stream<SyncJob> bind(Stream stream) => Stream.eventTransformed(
        stream,
        (sink) => DownloadJobTransformerSink(
          syncNode: syncNode,
          sink: sink,
        ),
      );

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom(this);
}
