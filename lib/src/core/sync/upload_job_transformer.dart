import 'dart:async';

import 'package:meta/meta.dart';

import '../store/store_event.dart';
import '../store/sync_object.dart';
import 'jobs/upload_job.dart';
import 'sync_job.dart';
import 'sync_node.dart';

@visibleForTesting
class UploadJobTransformerSink<T extends Object>
    implements EventSink<StoreEvent<SyncObject<T>>> {
  final SyncNode<T> syncNode;
  final EventSink<SyncJob> sink;

  UploadJobTransformerSink({
    required this.syncNode,
    required this.sink,
  });

  @override
  void add(StoreEvent<SyncObject<T>> event) {
    if (!event.value.locallyModified) {
      return;
    }

    sink.add(UploadJob(
      syncNode: syncNode,
      key: event.key,
      multipass: false,
    ));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      sink.addError(error, stackTrace);

  @override
  void close() => sink.close();
}

@visibleForTesting
class UploadJobTransformer<T extends Object>
    implements StreamTransformer<StoreEvent<SyncObject<T>>, SyncJob> {
  final SyncNode<T> syncNode;

  const UploadJobTransformer(this.syncNode);

  @override
  Stream<UploadJob<T>> bind(Stream<StoreEvent<SyncObject<T>>> stream) =>
      Stream.eventTransformed(
        stream,
        (sink) => UploadJobTransformerSink(
          syncNode: syncNode,
          sink: sink,
        ),
      );

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom(this);
}

extension UploadJobTransformerX<T extends Object>
    on Stream<StoreEvent<SyncObject<T>>> {
  Stream<SyncJob> asUploadJobs(SyncNode<T> syncNode) =>
      transform(UploadJobTransformer(syncNode));
}
