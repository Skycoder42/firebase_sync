// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/expandable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_error.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_job_executor.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockExecutableSyncJob extends Mock implements ExecutableSyncJob {}

class MockExpandableSyncJob extends Mock implements ExpandableSyncJob {}

class TestableExecutableSyncJob extends ExecutableSyncJob {
  final MockExecutableSyncJob mock;

  TestableExecutableSyncJob(this.mock);

  @override
  Future<ExecutionResult> executeImpl() => mock.executeImpl();
}

class TestableExpandableSyncJob extends ExpandableSyncJob {
  final MockExpandableSyncJob mock;

  TestableExpandableSyncJob(this.mock);

  @override
  Stream<ExecutableSyncJob> expandImpl() => mock.expandImpl();
}

void main() {
  ExecutableSyncJob createExecJob([
    FutureOr<ExecutionResult> execResult = const ExecutionResult.modified(),
  ]) {
    final mock = MockExecutableSyncJob();
    when(() => mock.executeImpl()).thenAnswer((i) async => execResult);
    return TestableExecutableSyncJob(mock);
  }

  ExpandableSyncJob createExpaJob([
    Stream<ExecutableSyncJob> jobs = const Stream.empty(),
  ]) {
    final mock = MockExpandableSyncJob();
    when(() => mock.expandImpl()).thenAnswer((i) => jobs);
    return TestableExpandableSyncJob(mock);
  }

  late SyncJobExecutor sut;

  setUp(() {
    sut = SyncJobExecutor();
  });

  tearDown(() async {
    await sut.close();
  });

  group('add', () {
    test('executes jobs and returns the job result', () async {
      final job = createExecJob();
      final result = sut.add(job);

      await expectLater(result, completion(SyncJobResult.success));

      verify(() => job.executeImpl());
    });

    test('asserts if already closed', () async {
      await sut.close();
      await expectLater(
        () => sut.add(createExecJob()),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('addAll', () {
    test('executes jobs in order and returns the job results', () async {
      final job1 = createExecJob(const ExecutionResult.noop());
      final job2 = createExecJob();
      final job3 = createExecJob(const ExecutionResult.noop());
      final result = sut.addAll([job1, job2, job3]);

      await expectLater(
        result,
        emitsInOrder(<dynamic>[
          SyncJobResult.noop,
          SyncJobResult.success,
          SyncJobResult.noop,
          emitsDone,
        ]),
      );

      verifyInOrder([
        () => job1.executeImpl(),
        () => job2.executeImpl(),
        () => job3.executeImpl(),
      ]);
    });

    test('asserts if already closed', () async {
      await sut.close();
      await expectLater(
        () => sut.addAll([createExecJob()]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // TODO test streaming

  group('processing', () {
    test('executes jobs one after another', () async {
      final completer = Completer<ExecutionResult>();
      final job1 = createExecJob(completer.future);
      final job2 = createExecJob();

      final result = sut.addAll([job1, job2]);
      expect(
        result,
        emitsInOrder(<dynamic>[
          SyncJobResult.noop,
          SyncJobResult.success,
          emitsDone,
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      verify(() => job1.executeImpl());
      verifyNever(() => job2.executeImpl());

      completer.complete(const ExecutionResult.noop());

      await Future<void>.delayed(const Duration(milliseconds: 100));
      verify(() => job2.executeImpl());
    });

    test('executes expanded jobs before the next one', () async {
      final job1 = createExecJob();
      final completer2 = Completer<ExecutionResult>();
      final job2 = createExecJob(completer2.future);
      final streamController3 = StreamController<ExecutableSyncJob>();
      final job3 = createExpaJob(streamController3.stream);
      final job4 = createExecJob(const ExecutionResult.noop());

      expect(sut.add(job3), completion(SyncJobResult.success));
      expect(sut.add(job4), completion(SyncJobResult.noop));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => job3.expandImpl());
      verifyNever(() => job1.executeImpl());
      verifyNever(() => job2.executeImpl());
      verifyNever(() => job4.executeImpl());

      streamController3..add(job1)..add(job2);
      expect(streamController3.close(), completes);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyInOrder([
        () => job1.executeImpl(),
        () => job2.executeImpl(),
      ]);
      verifyNever(() => job4.executeImpl());

      completer2.complete(const ExecutionResult.noop());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => job4.executeImpl());
    });

    test('schedules new jobs if continued', () async {
      final job11 = createExecJob(const ExecutionResult.noop());
      final job1 = createExecJob(ExecutionResult.continued(job11));
      final job2 = createExecJob();

      await expectLater(
        sut.addAll([job1, job2]),
        emitsInOrder(<dynamic>[
          SyncJobResult.noop,
          SyncJobResult.success,
          emitsDone,
        ]),
      );

      verifyInOrder([
        () => job1.executeImpl(),
        () => job2.executeImpl(),
        () => job11.executeImpl(),
      ]);
    });

    test('aborts all pending jobs if closed', () async {
      final completer21 = Completer<ExecutionResult>();
      final job1 = createExecJob();
      final job21 = createExecJob(completer21.future);
      final job211 = createExecJob();
      final job22 = createExecJob();
      final job2 = createExpaJob(Stream.fromIterable([job21, job22]));
      final job3 = createExecJob();

      expect(sut.add(job1), completion(SyncJobResult.success));
      expect(sut.add(job2), completion(SyncJobResult.aborted));
      expect(sut.add(job3), completion(SyncJobResult.aborted));
      expect(job21.result, completion(SyncJobResult.aborted));
      expect(job211.result, completion(SyncJobResult.aborted));
      expect(job22.result, completion(SyncJobResult.aborted));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyInOrder([
        () => job1.executeImpl(),
        () => job2.expandImpl(),
        () => job21.executeImpl(),
      ]);

      completer21.complete(ExecutionResult.continued(job211));
      await expectLater(sut.close(), completes);

      verifyNever(() => job211.executeImpl());
      verifyNever(() => job22.executeImpl());
      verifyNever(() => job3.executeImpl());
    });

    test('transforms job exceptions into SyncErrors', () async {
      final job1 = createExecJob(Future(() => throw Exception('error1')));
      final job2 = createExpaJob(Stream.error(Exception('error2')));
      final mock3 = MockExpandableSyncJob();
      when(() => mock3.expandImpl()).thenThrow(Exception('error3'));
      final job3 = TestableExpandableSyncJob(mock3);

      expect(
        sut.syncErrors,
        emitsInOrder(<dynamic>[
          isA<SyncError>().having(
            (e) => e.error.toString(),
            'error',
            'Exception: error1',
          ),
          isA<SyncError>().having(
            (e) => e.error.toString(),
            'error',
            'Exception: error2',
          ),
          isA<SyncError>().having(
            (e) => e.error.toString(),
            'error',
            'Exception: error3',
          ),
        ]),
      );

      expect(sut.add(job1), completion(SyncJobResult.failure));
      expect(sut.add(job2), completion(SyncJobResult.failure));
      expect(sut.add(job3), completion(SyncJobResult.failure));
    });
  });
}
