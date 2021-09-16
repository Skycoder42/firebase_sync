import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_delete_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_update_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/reset_job.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:firebase_sync/src/core/sync/transformers/download_job_transformer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockEventSink extends Mock implements EventSink<SyncJob> {}

class MockSyncNode extends Mock implements SyncNode<int> {}

class FakeCipherMessage extends Fake implements CipherMessage {}

class FakeSyncJob extends Fake implements SyncJob {}

class FakePatchSet extends Fake implements PatchSet<CipherMessage> {}

void main() {
  group('DownloadJobTransformerSink', () {
    final mockEventSink = MockEventSink();
    final mockSyncNode = MockSyncNode();

    late DownloadJobTransformerSink<int> sut;

    setUpAll(() {
      registerFallbackValue<SyncJob>(FakeSyncJob());
    });

    setUp(() {
      reset(mockEventSink);
      reset(mockSyncNode);

      sut = DownloadJobTransformerSink(
        syncNode: mockSyncNode,
        sink: mockEventSink,
      );
    });

    tearDown(() {
      verifyNoMoreInteractions(mockEventSink);

      sut.close();
    });

    group('add', () {
      test('reset event adds a reset job', () {
        final data = {
          'a': FakeCipherMessage(),
          'b': FakeCipherMessage(),
        };

        sut.add(StoreEvent.reset(data));

        verify(
          () => mockEventSink.add(
            any(
              that: isA<ResetJob>()
                  .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                  .having((j) => j.data, 'data', data),
            ),
          ),
        );
      });

      test('put event adds a download update job', () {
        const key = 'data-key';
        final value = FakeCipherMessage();

        sut.add(StoreEvent.put(key, value));

        verify(
          () => mockEventSink.add(
            any(
              that: isA<DownloadUpdateJob>()
                  .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                  .having((j) => j.key, 'key', key)
                  .having((j) => j.remoteCipher, 'remoteCipher', value)
                  .having(
                    (j) => j.conflictsTriggerUpload,
                    'conflictsTriggerUpload',
                    isFalse,
                  ),
            ),
          ),
        );
      });

      test('delete event adds a download delete job', () {
        const key = 'removed-key';

        sut.add(const StoreEvent.delete(key));

        verify(
          () => mockEventSink.add(
            any(
              that: isA<DownloadDeleteJob>()
                  .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                  .having((j) => j.key, 'key', key)
                  .having(
                    (j) => j.conflictsTriggerUpload,
                    'conflictsTriggerUpload',
                    isFalse,
                  ),
            ),
          ),
        );
      });

      test('patch event does nothing', () {
        sut.add(StoreEvent.patch('key', FakePatchSet()));

        verifyZeroInteractions(mockEventSink);
      });

      test('invalidPath event does nothing', () {
        sut.add(const StoreEvent.invalidPath('path'));

        verifyZeroInteractions(mockEventSink);
      });
    });

    test('addError forwards error to sink', () {
      final error = Exception();
      final stackTrace = StackTrace.current;

      sut.addError(error, stackTrace);

      verify(() => mockEventSink.addError(error, stackTrace));
    });

    test('close closes the sink', () {
      sut.close();

      verify(() => mockEventSink.close());
    });
  });

  group('DownloadJobTransformer', () {
    final mockSyncNode = MockSyncNode();

    late DownloadJobTransformer<int> sut;

    setUp(() {
      reset(mockSyncNode);

      sut = DownloadJobTransformer(mockSyncNode);
    });

    test('bind returns event transformed stream', () {
      const key = 'key';
      final stream = Stream.value(const StoreEvent<CipherMessage>.delete(key));

      final result = sut.bind(stream);

      expect(
        result,
        emitsInOrder(<dynamic>[
          isA<DownloadDeleteJob>(),
          emitsDone,
        ]),
      );
    });

    test('cast works', () {
      final result = sut.cast<StoreEvent<CipherMessage>, SyncJob>();

      expect(result, isNotNull);
    });
  });

  group('DownloadJobTransformerX', () {
    final mockSyncNode = MockSyncNode();

    setUp(() {
      reset(mockSyncNode);
    });

    test('asDownloadJobs creates event transformed stream', () {
      const key = 'key';
      final stream = Stream.value(const StoreEvent<CipherMessage>.delete(key));

      final result = stream.asDownloadJobs(mockSyncNode);

      expect(
        result,
        emitsInOrder(<dynamic>[
          isA<DownloadDeleteJob>(),
          emitsDone,
        ]),
      );
    });
  });
}
