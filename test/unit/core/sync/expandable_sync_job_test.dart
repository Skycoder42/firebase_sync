// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/expandable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockCompleter extends Mock implements Completer<SyncJobResult> {}

class MockEventSink extends Mock implements EventSink<ExecutableSyncJob> {}

class MockExecutableSyncJob extends Mock implements ExecutableSyncJob {}

class MockExpandableSyncJob extends Mock implements ExpandableSyncJob {}

class ExpandableSyncJobSut extends ExpandableSyncJob {
  final MockExpandableSyncJob mock;

  ExpandableSyncJobSut(this.mock);

  @override
  Stream<ExecutableSyncJob> expandImpl() => mock.expandImpl();
}

void main() {
  // TODO test exception handling

  MockExecutableSyncJob createExecJob([
    SyncJobResult result = SyncJobResult.success,
  ]) {
    final job = MockExecutableSyncJob();
    when(() => job.result).thenAnswer((i) async => result);
    return job;
  }

  group('SyncJobResultTransformerSink', () {
    final mockCompleter = MockCompleter();
    // ignore: close_sinks
    final mockEventSink = MockEventSink();

    late SyncJobResultTransformerSink sut;

    setUp(() {
      reset(mockCompleter);
      reset(mockEventSink);

      sut = SyncJobResultTransformerSink(mockCompleter, mockEventSink);
    });

    test('add forwards jobs to sink', () {
      final job = createExecJob();

      sut.add(job);

      verify(() => mockEventSink.add(job));
    });

    test('close forwards event to sink', () {
      sut.close();

      verify(() => mockEventSink.close());
    });

    test('addError forwards event to sink', () {
      final error = Exception();
      final stackTrace = StackTrace.current;
      sut.addError(error, stackTrace);

      verify(() => mockEventSink.addError(error, stackTrace));
    });

    group('result', () {
      test('returns noop for empty sink', () {
        sut.close();
        final result = verify(() => mockCompleter.complete(captureAny()))
            .captured
            .single as Future<SyncJobResult>;
        expect(result, completion(SyncJobResult.noop));
      });

      test('returns most relevant result of all elements', () {
        final job1 = createExecJob(SyncJobResult.noop);
        final job2 = createExecJob(SyncJobResult.failure);
        final job3 = createExecJob();

        sut
          ..add(job1)
          ..add(job2)
          ..add(job3)
          ..close();

        final result = verify(() => mockCompleter.complete(captureAny()))
            .captured
            .single as Future<SyncJobResult>;
        expect(result, completion(SyncJobResult.failure));
      });
    });
  });

  group('SyncJobResultTransformer', () {
    final mockCompleter = MockCompleter();

    late SyncJobResultTransformer sut;

    setUp(() {
      reset(mockCompleter);

      sut = SyncJobResultTransformer(mockCompleter);
    });

    test('bind returns event transformed stream', () async {
      final boundStream = sut.bind(const Stream.empty());
      await expectLater(boundStream, emitsDone);

      final result = verify(() => mockCompleter.complete(captureAny()))
          .captured
          .single as Future<SyncJobResult>;
      expect(result, completion(SyncJobResult.noop));
    });

    test('cast returns valid transformer', () {
      expect(sut.cast<ExecutableSyncJob, ExecutableSyncJob>(), isNotNull);
    });
  });

  group('ExpandableSyncJob', () {
    final sutMock = MockExpandableSyncJob();

    late ExpandableSyncJob sut;

    setUp(() {
      reset(sutMock);

      sut = ExpandableSyncJobSut(sutMock);
    });

    test('expands events with the SyncJobResultTransformer', () {
      final job1 = createExecJob(SyncJobResult.noop);
      final job2 = createExecJob(SyncJobResult.failure);
      final job3 = createExecJob();

      final testStream = Stream<ExecutableSyncJob>.fromIterable([
        job1,
        job2,
        job3,
      ]);

      when(() => sutMock.expandImpl()).thenAnswer((i) => testStream);

      final expandedStream = sut.expand();

      expect(
        expandedStream,
        emitsInOrder(<dynamic>[job1, job2, job3, emitsDone]),
      );
      expect(sut.result, completion(SyncJobResult.failure));
    });

    test('does nothing if already completed', () async {
      when(() => sutMock.expandImpl())
          .thenAnswer((i) => Stream.value(createExecJob()));

      sut.abort();
      final result = sut.expand();
      await expectLater(result, emitsDone);
      await expectLater(sut.result, completion(SyncJobResult.aborted));

      verifyNever(() => sutMock.expandImpl());
    });
  });
}
