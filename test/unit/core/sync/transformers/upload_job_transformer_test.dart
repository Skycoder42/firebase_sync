import 'dart:async';

import 'package:firebase_sync/src/core/store/store_event.dart';
import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:firebase_sync/src/core/sync/jobs/upload_job.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:firebase_sync/src/core/sync/transformers/upload_job_transformer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockEventSink extends Mock implements EventSink<SyncJob> {}

class MockSyncNode extends Mock implements SyncNode<int> {}

class FakeSyncJob extends Fake implements SyncJob {}

class FakeSyncObject extends Fake implements SyncObject<int> {
  @override
  final int changeState;

  FakeSyncObject(this.changeState);
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSyncJob());
  });

  group('UploadJobTransformerSink', () {
    final mockEventSink = MockEventSink();
    final mockSyncNode = MockSyncNode();

    late UploadJobTransformerSink<int> sut;

    setUp(() {
      reset(mockEventSink);
      reset(mockSyncNode);

      sut = UploadJobTransformerSink(
        syncNode: mockSyncNode,
        sink: mockEventSink,
      );
    });

    tearDown(() {
      verifyNoMoreInteractions(mockEventSink);

      sut.close();
    });

    group('add', () {
      test('adds upload job to event sink', () {
        const key = 'key';

        sut.add(StoreEvent(key: key, value: FakeSyncObject(1)));

        verify(
          () => mockEventSink.add(
            any(
              that: isA<UploadJob>()
                  .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                  .having((j) => j.key, 'key', key)
                  .having((j) => j.multipass, 'multipass', isFalse),
            ),
          ),
        );
      });

      test('add does nothing if not locally modified', () {
        const key = 'key';

        sut.add(StoreEvent(key: key, value: FakeSyncObject(0)));

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

  group('UploadJobTransformer', () {
    final mockSyncNode = MockSyncNode();

    late UploadJobTransformer<int> sut;

    setUp(() {
      reset(mockSyncNode);

      sut = UploadJobTransformer(mockSyncNode);
    });

    test('bind returns event transformed stream', () {
      const key = 'key';
      final stream = Stream.value(
        StoreEvent(key: key, value: FakeSyncObject(1)),
      );

      final result = sut.bind(stream);

      expect(
        result,
        emitsInOrder(<dynamic>[
          isA<UploadJob>(),
          emitsDone,
        ]),
      );
    });

    test('cast works', () {
      final result = sut.cast<StoreEvent<SyncObject<int>>, SyncJob>();

      expect(result, isNotNull);
    });
  });

  group('UploadJobTransformerX', () {
    final mockSyncNode = MockSyncNode();

    setUp(() {
      reset(mockSyncNode);
    });

    test('asDownloadJobs creates event transformed stream', () {
      const key = 'key';
      final stream = Stream.value(
        StoreEvent<SyncObject<int>>(key: key, value: FakeSyncObject(1)),
      );

      final result = stream.asUploadJobs(mockSyncNode);

      expect(
        result,
        emitsInOrder(<dynamic>[
          isA<UploadJob>(),
          emitsDone,
        ]),
      );
    });
  });
}
