import 'dart:async';

import 'package:firebase_sync/src/core/sync/sync_error.dart';
import 'package:firebase_sync/src/core/sync/transformers/sync_error_transformer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockEventSink extends Mock implements EventSink<SyncError> {}

void main() {
  group('SyncErrorTransformerSink', () {
    final mockEventSink = MockEventSink();

    late SyncErrorTransformerSink sut;

    setUp(() {
      reset(mockEventSink);

      sut = SyncErrorTransformerSink(mockEventSink);
    });

    tearDown(() {
      verifyNoMoreInteractions(mockEventSink);

      sut.close();
    });

    test('add does nothing', () {
      sut.add(42);

      verifyZeroInteractions(mockEventSink);
    });

    test('addError adds a sync error event to the sink', () {
      final error = Exception();
      final stackTrace = StackTrace.current;

      sut.addError(error, stackTrace);

      verify(() => mockEventSink.add(SyncError(error, stackTrace)));
    });

    test('close closes event sink', () {
      sut.close();

      verify(() => mockEventSink.close());
    });
  });

  group('SyncErrorTransformer', () {
    late SyncErrorTransformer sut;

    setUp(() {
      sut = const SyncErrorTransformer();
    });

    test('bind returns event transformed stream', () {
      final error = Exception();
      final stackTrace = StackTrace.current;
      final stream = Stream<dynamic>.error(error, stackTrace);

      final result = sut.bind(stream);

      expect(
        result,
        emitsInOrder(<dynamic>[
          SyncError(error, stackTrace),
          emitsDone,
        ]),
      );
    });

    test('cast works', () {
      final result = sut.cast<dynamic, SyncError>();

      expect(result, isNotNull);
    });
  });

  group('SyncErrorTransformerX', () {
    test('asDownloadJobs creates event transformed stream', () {
      final error = Exception();
      final stackTrace = StackTrace.current;
      final stream = Stream<dynamic>.error(error, stackTrace);

      final result = stream.mapSyncErrors();

      expect(
        result,
        emitsInOrder(<dynamic>[
          SyncError(error, stackTrace),
          emitsDone,
        ]),
      );
    });
  });
}
