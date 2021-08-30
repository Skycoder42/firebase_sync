// ignore_for_file: invalid_use_of_protected_member
import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockExecutableSyncJob extends Mock implements ExecutableSyncJob {}

class ExecutableSyncJobSut extends ExecutableSyncJob {
  final MockExecutableSyncJob mock;

  ExecutableSyncJobSut(this.mock);

  @override
  Future<ExecutionResult> executeImpl() => mock.executeImpl();
}

void main() {
  group('ExecutableSyncJobSut', () {
    final sutMock = MockExecutableSyncJob();

    late ExecutableSyncJobSut sut;

    setUp(() {
      reset(sutMock);

      sut = ExecutableSyncJobSut(sutMock);
    });

    group('execute', () {
      setUp(() {
        when(() => sutMock.executeImpl()).thenAnswer(
          (i) async => const ExecutionResult.modified(),
        );
      });

      test('calls executeImpl', () async {
        await sut.execute();

        verify(() => sutMock.executeImpl());
      });

      test('calling twice only executes once', () async {
        await sut.execute();
        await sut.execute();

        verify(() => sutMock.executeImpl()).called(1);
      });

      test('result returns success if executeImpl returns modified', () {
        expect(sut.execute(), completion(isNull));
        expect(sut.result, completion(SyncJobResult.success));
      });

      test('result returns noop if executeImpl returns noop', () {
        when(() => sutMock.executeImpl())
            .thenAnswer((i) async => const ExecutionResult.noop());

        expect(sut.execute(), completion(isNull));
        expect(sut.result, completion(SyncJobResult.noop));
      });

      test('result returns failure if executeImpl throws', () {
        when(() => sutMock.executeImpl()).thenThrow(Exception());

        expect(sut.execute, throwsA(isA<Exception>()));

        expect(sut.result, completion(SyncJobResult.failure));
      });

      test('returns result of next job if specified', () {
        const result = SyncJobResult.aborted;
        final nextJob = MockExecutableSyncJob();
        when(() => nextJob.result).thenAnswer((i) async => result);

        when(() => sutMock.executeImpl())
            .thenAnswer((i) async => ExecutionResult.continued(nextJob));

        expect(sut.execute(), completion(nextJob));
        expect(sut.result, completion(SyncJobResult.aborted));
      });

      test('result returns abort if aborted', () {
        sut.abort();

        expect(sut.result, completion(SyncJobResult.aborted));
        expect(sut.execute(), completion(isNull));
      });

      test('calling after aborting does nothing', () async {
        sut.abort();

        await expectLater(sut.execute(), completion(isNull));
        await expectLater(sut.result, completion(SyncJobResult.aborted));

        verifyNever(() => sutMock.executeImpl());
      });
    });
  });
}
