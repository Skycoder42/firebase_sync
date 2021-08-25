import 'dart:async';

import 'package:meta/meta.dart';

import '../sync_error.dart';

extension SyncErrorTransformerX on Stream<void> {
  Stream<SyncError> mapSyncErrors() => transform(const SyncErrorTransformer());
}

@visibleForTesting
class SyncErrorTransformerSink implements EventSink<void> {
  final EventSink<SyncError> sink;

  SyncErrorTransformerSink(this.sink);

  @override
  void add(void event) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      sink.add(SyncError(error, stackTrace));

  @override
  void close() => sink.close();
}

@visibleForTesting
class SyncErrorTransformer implements StreamTransformer<void, SyncError> {
  const SyncErrorTransformer();

  @override
  Stream<SyncError> bind(Stream<void> stream) => Stream.eventTransformed(
        stream,
        (sink) => SyncErrorTransformerSink(sink),
      );

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom(this);
}
