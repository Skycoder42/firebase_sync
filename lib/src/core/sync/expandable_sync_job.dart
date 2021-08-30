import 'dart:async';

import 'package:meta/meta.dart';

import 'executable_sync_job.dart';
import 'sync_job.dart';

abstract class ExpandableSyncJob extends SyncJob {
  @nonVirtual
  Stream<ExecutableSyncJob> expand() {
    if (completer.isCompleted) {
      return const Stream.empty();
    }

    try {
      return expandImpl().transform(SyncJobResultTransformer(completer));
    } catch (e) {
      completer.complete(SyncJobResult.failure);
      rethrow;
    }
  }

  @protected
  Stream<ExecutableSyncJob> expandImpl();
}

@visibleForTesting
class SyncJobResultTransformerSink implements EventSink<ExecutableSyncJob> {
  final Completer<SyncJobResult> completer;
  final EventSink<ExecutableSyncJob> sink;

  final _results = <Future<SyncJobResult>>{};

  SyncJobResultTransformerSink(this.completer, this.sink);

  @override
  void add(ExecutableSyncJob job) {
    sink.add(job);
    _results.add(job.result);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    sink.addError(error, stackTrace);
    _results.add(Future.value(SyncJobResult.failure));
  }

  @override
  void close() {
    sink.close();
    completer.complete(
      Stream.fromFutures(_results).fold(
        SyncJobResult.noop,
        (a, b) => a.combine(b),
      ),
    );
  }
}

@visibleForTesting
class SyncJobResultTransformer
    implements StreamTransformer<ExecutableSyncJob, ExecutableSyncJob> {
  final Completer<SyncJobResult> completer;

  SyncJobResultTransformer(this.completer);

  @override
  Stream<ExecutableSyncJob> bind(Stream<ExecutableSyncJob> stream) =>
      Stream.eventTransformed(
        stream,
        (sink) => SyncJobResultTransformerSink(completer, sink),
      );

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom(this);
}
