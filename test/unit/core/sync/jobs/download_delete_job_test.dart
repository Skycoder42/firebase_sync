// ignore_for_file: invalid_use_of_protected_member
import 'dart:typed_data';

import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/store/update_action.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_delete_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/upload_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class MockConflictResolver extends Mock implements ConflictResolver<int> {}

void main() {
  group('DownloadDeleteJob', () {
    const key = 'delete-key';
    final mockSyncNode = MockSyncNode();
    final mockSyncObjectStore = MockSyncObjectStore();
    final mockConflictResolver = MockConflictResolver();

    late DownloadDeleteJob<int> sut;

    void whenUpdate({
      required SyncObject<int>? oldData,
      required SyncObject<int>? newData,
      required dynamic resultMatcher,
    }) {
      when(() => mockSyncObjectStore.update(any(), any())).thenAnswer((i) {
        final callback = i.positionalArguments[1] as UpdateFn<int>;
        final result = callback(oldData);
        expect(result, resultMatcher);
        return newData;
      });
    }

    setUp(() {
      reset(mockSyncNode);
      reset(mockSyncObjectStore);
      reset(mockConflictResolver);

      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);
      when(() => mockSyncNode.conflictResolver)
          .thenReturn(mockConflictResolver);

      sut = DownloadDeleteJob(
        key: key,
        syncNode: mockSyncNode,
        conflictsTriggerUpload: true,
      );
    });

    group('executeImpl', () {
      test('does nothing if there is no local data', () async {
        whenUpdate(
          oldData: null,
          newData: null,
          resultMatcher: const UpdateAction.none(),
        );

        final result = await sut.executeImpl();

        expect(result, const ExecutionResult.noop());
        verify(() => mockSyncObjectStore.update(key, any()));
      });

      test('deletes the local data if it has not been modified', () async {
        whenUpdate(
          oldData: SyncObject.remote(10, Uint8List(SyncObject.remoteTagMin)),
          newData: null,
          resultMatcher: const UpdateAction.delete(),
        );

        final result = await sut.executeImpl();

        expect(result, const ExecutionResult.modified());
        verify(() => mockSyncObjectStore.update(key, any()));
      });

      test(
        'does nothing if local data has been modified but '
        'does not expect remote data',
        () async {
          whenUpdate(
            oldData: SyncObject.local(10),
            newData: SyncObject.local(10),
            resultMatcher: const UpdateAction.none(),
          );

          final result = await sut.executeImpl();

          expect(result, const ExecutionResult.noop());
          verify(() => mockSyncObjectStore.update(key, any()));
        },
      );

      test('resolves conflicts hand triggers upload if required', () async {
        final newData = SyncObject(
          value: 5,
          changeState: 6,
          remoteTag: SyncObject.noRemoteDataTag,
        );

        when(
          () => mockConflictResolver.resolve(
            any(),
            local: any(named: 'local'),
            remote: any(named: 'remote'),
          ),
        ).thenReturn(const ConflictResolution.update(5));

        whenUpdate(
          oldData: SyncObject(
            value: 10,
            changeState: 5,
            remoteTag: Uint8List(SyncObject.remoteTagMin),
          ),
          newData: newData,
          resultMatcher: UpdateAction.update(newData),
        );

        final result = await sut.executeImpl();

        result.maybeWhen(
          orElse: () =>
              fail('Expected ExecutionResult.continued, but got $result'),
          continued: (job) => expect(
            job,
            isA<UploadJob<int>>()
                .having((j) => j.key, 'key', key)
                .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                .having((j) => j.multipass, 'multipass', isFalse),
          ),
        );

        verify(() => mockSyncObjectStore.update(key, any()));
        verify(
          () => mockConflictResolver.resolve(
            key,
            local: 10,
            remote: null,
          ),
        );
      });
    });
  });
}
