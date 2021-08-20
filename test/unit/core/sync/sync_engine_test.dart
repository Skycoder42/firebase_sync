// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:firebase_sync/src/core/sync/sync_engine.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'package:tuple/tuple.dart';

class MockSyncJob extends Mock implements SyncJob {}

extension SyncEngineTestX on SyncEngine {
  static int skipErrors = 0;

  void logErrors() {
    // ignore: avoid_print
    syncErrors.listen((e) => skipErrors > 0 ? --skipErrors : print(e));
  }
}

class SyncJobSut extends SyncJob {
  final MockSyncJob mock;

  SyncJobSut(this.mock);

  @override
  Future<SyncJobExecutionResult> execute() => mock.execute();

  @override
  String get key => mock.key;

  @override
  String get storeName => mock.storeName;
}

void main() {
  SyncJobSut createJob({
    FutureOr<SyncJobExecutionResult> result =
        const SyncJobExecutionResult.success(),
    String storeName = '_default',
    String key = '_default',
  }) {
    final job = SyncJobSut(MockSyncJob());
    when(() => job.mock.execute()).thenAnswer((i) async => result);
    when(() => job.mock.storeName).thenReturn(storeName);
    when(() => job.mock.key).thenReturn(key);
    return job;
  }

  Future<void> pump([int? durationMillis]) => Future<void>.delayed(
        durationMillis != null
            ? Duration(milliseconds: durationMillis)
            : Duration.zero,
      );

  setUp(() {
    SyncEngineTestX.skipErrors = 0;
  });

  tearDown(() {
    expect(SyncEngineTestX.skipErrors, 0);
  });

  group('construction', () {
    test('returns correct default parallel jobs', () {
      final sut = SyncEngine()..logErrors();
      expect(sut.parallelJobs, SyncEngine.defaultParallelJobs);
    });

    test('returns correct custom parallel jobs', () {
      final sut = SyncEngine(parallelJobs: 10)..logErrors();
      expect(sut.parallelJobs, 10);
    });
  });

  group('running', () {
    late SyncEngine sut;

    setUp(() {
      sut = SyncEngine()..logErrors();
    });

    tearDown(() async {
      await sut.dispose();
    });

    test('is running and not paused', () {
      expect(sut.paused, isFalse);
    });

    test('execute added job', () async {
      final job = createJob();
      final result = await sut.addJob(job);
      expect(result, SyncJobResult.success);

      verify(() => job.mock.execute());
    });

    test('execute multiple added jobs', () async {
      final jobs = List.generate(
        15,
        (index) => createJob(key: index.toString()),
      );
      final result = await sut.addJobs(jobs);
      expect(result, List.filled(jobs.length, SyncJobResult.success));

      verifyInOrder(
        jobs
            .map(
              (job) => () => job.mock.execute(),
            )
            .toList(),
      );
    });

    test('runs at most parallelJobs at once', () async {
      final completer = Completer<SyncJobExecutionResult>();
      final jobs = <SyncJobSut>[];
      for (var i = 0; i <= sut.parallelJobs; ++i) {
        jobs.add(createJob(
          result: completer.future,
          key: i.toString(),
        ));
      }

      // expect later, but contine test execution
      expect(
        sut.addJobs(jobs),
        completion(
          List.filled(jobs.length, SyncJobResult.success),
        ),
      );

      // run job executions
      await pump();

      // verifiy only the first batch has started
      verifyInOrder(
        jobs
            .take(sut.parallelJobs)
            .map((job) => () => job.mock.execute())
            .toList(),
      );
      jobs
          .skip(sut.parallelJobs)
          .map((job) => verifyNever(() => job.execute()))
          .toList();

      completer.complete(const SyncJobExecutionResult.success());
      // run job executions
      await pump(500);

      verifyInOrder(
        jobs
            .skip(sut.parallelJobs)
            .map((job) => () => job.mock.execute())
            .toList(),
      );
    });

    test('jobs for the same target are not run in parallel', () async {
      final c1 = Completer<SyncJobExecutionResult>();
      final job1 = createJob(storeName: 's1', key: 'k1', result: c1.future);
      final job2 = createJob(storeName: 's1', key: 'k1');
      final job3 = createJob(storeName: 's1', key: 'k2');
      final job4 = createJob(storeName: 's2', key: 'k1');

      expect(
        sut.addJobs([job1, job2, job3, job4]),
        completion([
          SyncJobResult.noop,
          SyncJobResult.success,
          SyncJobResult.success,
          SyncJobResult.success,
        ]),
      );
      await pump();

      verify(() => job1.mock.execute());
      verifyNever(() => job2.mock.execute());
      verify(() => job3.mock.execute());
      verify(() => job4.mock.execute());

      c1.complete(const SyncJobExecutionResult.noop());
      await pump(500);

      verify(() => job2.mock.execute());
    });

    test(
      'job execution only finishes when the continuation job finished as well',
      () async {
        final c1 = Completer<SyncJobExecutionResult>();
        final c2 = Completer<SyncJobExecutionResult>();
        final job1 = createJob(key: 'k1', result: c1.future);
        final job2 = createJob(key: 'k2', result: c2.future);
        final job3 = createJob(
          key: 'k1',
          result: const SyncJobExecutionResult.noop(),
        );

        expect(sut.addJob(job1), completion(SyncJobResult.success));
        expect(sut.addJob(job3), completion(SyncJobResult.noop));
        await pump();
        verify(() => job1.mock.execute());
        verifyNever(() => job3.mock.execute());

        c1.complete(SyncJobExecutionResult.next(job2));
        await pump();
        verifyNever(() => job2.mock.execute());
        verifyNever(() => job3.mock.execute());

        expect(sut.addJob(job2), completion(SyncJobResult.success));
        await pump();
        verify(() => job2.mock.execute());

        c2.complete(const SyncJobExecutionResult.success());
        await pump();
        verify(() => job3.mock.execute());
      },
    );

    test('pausing prevents job execution', () async {
      sut.paused = false;
      expect(sut.paused, isFalse);

      final c = Completer<SyncJobExecutionResult>();
      final job1 = createJob(storeName: 's1', result: c.future);
      final job2 = createJob(storeName: 's1', result: c.future);
      final job3 = createJob(storeName: 's2', result: c.future);

      expect(sut.addJobs([job1, job2]), completes);
      await pump();

      verify(() => job1.mock.execute());
      verifyNever(() => job2.mock.execute());
      verifyNever(() => job3.mock.execute());

      sut.paused = true;
      expect(sut.paused, isTrue);
      expect(sut.addJob(job3), completes);

      c.complete(const SyncJobExecutionResult.success());
      await pump(500);

      verifyNever(() => job2.mock.execute());
      verifyNever(() => job3.mock.execute());

      sut.paused = false;
      expect(sut.paused, isFalse);
      await pump();

      verify(() => job2.mock.execute());
      verify(() => job3.mock.execute());
    });

    test('adjust parallel job runs dynamically', () async {
      sut.parallelJobs = 5;
      expect(sut.parallelJobs, 5);

      final actions = List.generate(
        10,
        (index) {
          final completer = Completer<SyncJobExecutionResult>();
          return Tuple2(
            createJob(key: index.toString(), result: completer.future),
            completer,
          );
        },
      );

      expect(sut.addJobs(actions.map((a) => a.item1).toList()), completes);
      await pump();

      verifyInOrder(
        actions.take(5).map((a) => () => a.item1.mock.execute()).toList(),
      );
      actions
          .skip(5)
          .map((a) => verifyNever(() => a.item1.mock.execute()))
          .toList();

      sut.parallelJobs = 3;
      expect(sut.parallelJobs, 3);
      await pump();

      actions
          .skip(5)
          .map((a) => verifyNever(() => a.item1.mock.execute()))
          .toList();

      actions
          .take(5)
          .map((a) => a.item2.complete(const SyncJobExecutionResult.noop()))
          .toList();
      await pump(500);

      verifyInOrder(
        actions
            .skip(5)
            .take(3)
            .map((a) => () => a.item1.mock.execute())
            .toList(),
      );
      actions
          .skip(8)
          .map((a) => verifyNever(() => a.item1.mock.execute()))
          .toList();

      sut.parallelJobs = 5;
      expect(sut.parallelJobs, 5);
      await pump();

      verifyInOrder(
        actions.skip(8).map((a) => () => a.item1.mock.execute()).toList(),
      );

      actions
          .skip(5)
          .map((a) => a.item2.complete(const SyncJobExecutionResult.noop()))
          .toList();
    });

    test('sync errors are handled and reported correctly', () {
      SyncEngineTestX.skipErrors = 10;

      final jobs = List.generate(
        10,
        (index) => createJob(key: index.toString()),
      );
      for (final job in jobs) {
        when(() => job.mock.execute()).thenThrow(Exception(job.key));
      }
      when(() => jobs.last.mock.execute()).thenThrow(Error());

      expect(
        sut.addJobs(jobs),
        completion(List.filled(10, SyncJobResult.failure)),
      );
    });

    group('streams', () {
      test('completes immediatly for empty streams', () {
        sut.addJobStream(const Stream.empty());
      });

      test('add jobs from stream', () {
        final job = createJob();
        sut.addJobStream(Stream.value(job));

        expect(job.result, completion(SyncJobResult.success));
      });

      test('continues stream even if errors happen', () {
        SyncEngineTestX.skipErrors = 1;

        final job1 = createJob();
        final job2 = createJob();
        final stream = Stream<SyncJobSut>.fromFutures([
          Future.value(job1),
          Future.error('test', StackTrace.current),
          Future.value(job2),
        ]);

        sut.addJobStream(stream);
        expect(job1.result, completion(SyncJobResult.success));
        expect(job2.result, completion(SyncJobResult.success));
      });

      test('cancelling works as expected', () async {
        final job1 = createJob();
        final job2 = createJob();
        final stream = Stream.fromFutures([
          Future.value(job1),
          Future.delayed(const Duration(milliseconds: 100), () => job2),
        ]);

        final token = sut.addJobStream(stream);
        await pump();

        expect(token.cancel(), completes);
        expect(job1.result, completion(SyncJobResult.success));
        expect(job2.result, doesNotComplete);

        await pump(500);

        verify(() => job1.mock.execute());
        verifyNever(() => job2.mock.execute());

        // canceling again does nothing
        expect(token.cancel(), completes);
      });

      test('does not add events in paused state', () async {
        sut.paused = true;
        final job = createJob();
        sut.addJobStream(Stream.value(job));
        await pump();

        await sut.dispose();

        verifyNever(() => job.mock.execute());
        expect(job.result, doesNotComplete);

        await pump(500);
      });

      test('correctly handles paused switches', () async {
        final job1 = createJob();
        final job2 = createJob();
        final job2Completer = Completer<SyncJobSut>();
        final stream = Stream.fromFutures([
          Future.value(job1),
          job2Completer.future,
        ]);

        sut
          ..paused = true
          ..addJobStream(stream);
        expect(job1.result, completion(SyncJobResult.success));
        expect(job2.result, completion(SyncJobResult.success));

        await pump(100);

        verifyNever(() => job1.mock.execute());
        verifyNever(() => job2.mock.execute());

        sut.paused = false;
        await pump(100);
        sut.paused = true;
        job2Completer.complete(job2);
        await pump(100);

        verify(() => job1.mock.execute());
        verifyNever(() => job2.mock.execute());

        sut.paused = false;
        await pump(100);

        verify(() => job2.mock.execute());
      });
    });

    group('dispose', () {
      test('stops job execution', () async {
        final completer = Completer<SyncJobExecutionResult>();
        final jobs = List.generate(
          10,
          (index) => createJob(
            key: index.toString(),
            result: completer.future,
          ),
        );

        expect(
          sut.addJobs(jobs),
          completion(
            List.filled(5, SyncJobResult.success)
                .followedBy(List.filled(5, SyncJobResult.aborted)),
          ),
        );
        await pump();

        verifyInOrder(
          jobs.take(5).map((job) => () => job.mock.execute()).toList(),
        );
        jobs
            .skip(5)
            .map((job) => verifyNever(() => job.mock.execute()))
            .toList();

        expect(sut.dispose(), completes);
        completer.complete(const SyncJobExecutionResult.success());
        await pump();

        jobs
            .skip(5)
            .map((job) => verifyNever(() => job.mock.execute()))
            .toList();
      });

      test('disposing twice returns the same future', () {
        final f1 = sut.dispose();
        final f2 = sut.dispose();

        expect(f1, same(f2));
      });
    });
  });

  group('disposed', () {
    late SyncEngine sut;

    setUp(() {
      sut = SyncEngine()
        ..logErrors()
        ..dispose();
    });

    test('adding jobs etc. asserts or does nothing', () {
      expect(sut.dispose(), completes);

      expect(
        () => sut.addJob(createJob()),
        throwsA(isA<StateError>()),
      );
      expect(
        () => sut.addJobs([createJob()]),
        throwsA(isA<StateError>()),
      );
      expect(
        () => sut.addJobStream(const Stream.empty()),
        throwsA(isA<StateError>()),
      );
      sut
        ..parallelJobs = 10
        ..paused = true
        ..paused = false;
    });
  });
}

// TODO purgeJobs
