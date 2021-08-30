import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/expandable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_data.dart';

class SutSyncJob extends SyncJob {}

class MockExpandableSyncJob extends Mock implements ExpandableSyncJob {}

class MockExecutableSyncJob extends Mock implements ExecutableSyncJob {}

void main() {
  testData<Tuple2<SyncJobResult, int>>(
    'SyncJobResult values are sorted by priority',
    const [
      Tuple2(SyncJobResult.noop, 0),
      Tuple2(SyncJobResult.success, 1),
      Tuple2(SyncJobResult.aborted, 2),
      Tuple2(SyncJobResult.failure, 3),
    ],
    (fixture) {
      expect(fixture.item1.index, fixture.item2);
    },
  );

  group('SyncJob', () {
    late SyncJob sut;

    setUp(() {
      sut = SutSyncJob();
    });

    test('result returns completer result', () {
      expect(sut.result, completion(SyncJobResult.noop));
      sut.completer.complete(SyncJobResult.noop);
    });

    test('abort completes with SyncJobResult.aborted', () {
      expect(sut.result, completion(SyncJobResult.aborted));
      sut.abort();
    });
  });

  group('SyncJobExpandX', () {
    test('ExpandableSyncJobs are expanded', () {
      final sut = MockExpandableSyncJob();
      when(() => sut.expand()).thenAnswer((i) => const Stream.empty());

      // ignore: unnecessary_cast
      final result = (sut as SyncJob).expand();
      expect(result, neverEmits(anything));

      verify(() => sut.expand());
    });

    test('ExecutableSyncJobs are expanded', () {
      final sut = MockExecutableSyncJob();

      // ignore: unnecessary_cast
      final result = (sut as SyncJob).expand();
      expect(result, emits(sut));
    });
  });
}
