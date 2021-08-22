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

    return expandImpl().transform(SyncJobResultTransformer(completer));
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
  void addError(Object error, [StackTrace? stackTrace]) =>
      sink.addError(error, stackTrace);

  @override
  void close() {
    sink.close();
    completer.complete(
      Stream.fromFutures(_results).reduce(_reduceMostRelevant),
    );
  }

  static SyncJobResult _reduceMostRelevant(
    SyncJobResult previous,
    SyncJobResult element,
  ) =>
      element.index > previous.index ? element : previous;
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
