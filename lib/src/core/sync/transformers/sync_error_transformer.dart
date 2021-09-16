import 'dart:async';

import 'package:meta/meta.dart';

import '../sync_error.dart';

extension SyncErrorTransformerX on Stream {
  Stream<SyncError> mapSyncErrors() => transform(const SyncErrorTransformer());
}

@visibleForTesting
class SyncErrorTransformerSink implements EventSink<dynamic> {
  final EventSink<SyncError> sink;

  SyncErrorTransformerSink(this.sink);

  @override
  void add(dynamic event) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      sink.add(SyncError(error, stackTrace));

  @override
  void close() => sink.close();
}

@visibleForTesting
class SyncErrorTransformer implements StreamTransformer<dynamic, SyncError> {
  const SyncErrorTransformer();

  @override
  Stream<SyncError> bind(Stream stream) => Stream.eventTransformed(
        stream,
        (sink) => SyncErrorTransformerSink(sink),
      );

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<dynamic, SyncError, RS, RT>(this);
}
