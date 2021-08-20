// ignore_for_file: invalid_use_of_protected_member
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'package:tuple/tuple.dart';

import '../../../test_data.dart';

class MockSyncJob extends Mock implements SyncJob {}

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
  final sutMock = MockSyncJob();

  late SyncJobSut sut;

  setUp(() {
    reset(sutMock);

    sut = SyncJobSut(sutMock);
  });

  testData<Tuple3<String, String, bool>>(
    'check conflict compares storeName and key',
    const [
      Tuple3('store1', 'key1', false),
      Tuple3('store1', 'key2', false),
      Tuple3('store2', 'key1', false),
      Tuple3('store2', 'key2', true),
    ],
    (fixture) {
      when(() => sutMock.storeName).thenReturn(fixture.item1);
      when(() => sutMock.key).thenReturn(fixture.item2);

      final anotherMock = MockSyncJob();
      when(() => anotherMock.storeName).thenReturn('store2');
      when(() => anotherMock.key).thenReturn('key2');

      final hasConflict = sut.checkConflict(anotherMock);
      expect(hasConflict, fixture.item3);
    },
  );

  group('call', () {
    setUp(() {
      when(() => sutMock.execute()).thenAnswer(
        (i) async => const SyncJobExecutionResult.success(),
      );
    });

    test('calls execute', () async {
      await sut.call();

      verify(() => sutMock.execute());
    });

    test('calling twice only executes once', () async {
      await sut.call();
      await sut.call();

      verify(() => sutMock.execute()).called(1);
    });

    test('result returns success if execute returns success', () {
      expect(sut.call(), completes);
      expect(sut.result, completion(SyncJobResult.success));
    });

    test('result returns noop if execute returns noop', () {
      when(() => sutMock.execute())
          .thenAnswer((i) async => const SyncJobExecutionResult.noop());

      expect(sut.call(), completes);
      expect(sut.result, completion(SyncJobResult.noop));
    });

    test('result returns failure if execute throws', () {
      when(() => sutMock.execute()).thenThrow(Exception());

      expect(sut.call, throwsA(isA<Exception>()));

      expect(sut.result, completion(SyncJobResult.failure));
    });

    test('returns result of next job if specified', () {
      const result = SyncJobResult.aborted;
      final nextJob = MockSyncJob();
      when(() => nextJob.result).thenAnswer((i) async => result);

      when(() => sutMock.execute())
          .thenAnswer((i) async => SyncJobExecutionResult.next(nextJob));

      expect(sut.call(), completes);
      expect(sut.result, completion(SyncJobResult.aborted));
    });

    test('result returns abort if aborted', () {
      sut.abort();

      expect(sut.result, completion(SyncJobResult.aborted));
      expect(sut.call(), completes);
    });

    test('calling after aborting does nothing', () {
      sut.abort();
      expect(sut.call(), completes);

      expect(sut.result, completion(SyncJobResult.aborted));

      verifyNever(() => sutMock.execute());
    });
  });
}
