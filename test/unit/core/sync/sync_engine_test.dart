// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:firebase_sync/src/core/sync/sync_engine.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

class MockSyncJob extends Mock implements SyncJob {}

class SyncJobSut extends SyncJob {
  final MockSyncJob mock;

  SyncJobSut(this.mock);

  @override
  Future<bool> execute() => mock.execute();

  @override
  String get key => mock.key;

  @override
  String get storeName => mock.storeName;
}

void main() {
  SyncJobSut createJob({
    FutureOr<bool> result = true,
    String? storeName,
    String? key,
  }) {
    final job = SyncJobSut(MockSyncJob());
    when(() => job.mock.execute()).thenAnswer((i) async => result);
    if (storeName != null) {
      when(() => job.mock.storeName).thenReturn(storeName);
    }
    if (key != null) {
      when(() => job.mock.storeName).thenReturn(key);
    }
    return job;
  }

  group('construction', () {
    test('returns correct default parallel jobs', () {
      final sut = SyncEngine();
      expect(sut.parallelJobs, SyncEngine.defaultParallelJobs);
    });

    test('returns correct custom parallel jobs', () {
      final sut = SyncEngine(parallelJobs: 10);
      expect(sut.parallelJobs, 10);
    });
  });

  group('running', () {
    late SyncEngine sut;

    setUp(() {
      sut = SyncEngine()..start();
    });

    test('is running and not paused', () {
      expect(sut.running, isTrue);
      expect(sut.paused, isFalse);
    });

    test('executed added job', () async {
      final job = createJob();
      final result = await sut.addJob(job);
      expect(result, SyncJobResult.success);

      verify(() => job.mock.execute());
    });

    test('runs at most parallelJobs at once', () {
      final completer = Completer<bool>();
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
          List.filled(sut.parallelJobs + 1, SyncJobResult.success),
        ),
      );
    });
  });
}
