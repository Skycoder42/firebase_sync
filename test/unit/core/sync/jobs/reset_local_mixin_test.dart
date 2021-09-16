// ignore_for_file: invalid_use_of_protected_member
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/expandable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/reset_local_mixin.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'matchers.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class FakeCipherMessage extends Fake implements CipherMessage {}

class Sut extends ExpandableSyncJob with ResetLocalMixin<int> {
  @override
  final SyncNode<int> syncNode;

  Sut(this.syncNode);

  @override
  Stream<ExecutableSyncJob> expandImpl() => throw UnimplementedError();
}

void main() {
  group('ResetLocalMixin', () {
    final mockSyncNode = MockSyncNode();
    final mockSyncObjectStore = MockSyncObjectStore();

    late Sut sut;

    setUp(() {
      reset(mockSyncNode);
      reset(mockSyncObjectStore);

      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);

      sut = Sut(mockSyncNode);
    });

    group('generateJobs', () {
      test('calls localStore.rawKeys to get current key state', () {
        when(() => mockSyncObjectStore.rawKeys).thenReturn(const []);

        sut.generateJobs(
          data: const {},
          conflictsTriggerUpload: false,
        );

        verify(() => mockSyncObjectStore.rawKeys);
      });

      test('creates iterable with all jobs to delete and update', () {
        const currentKeys = ['a', 'b', 'c', 'd'];
        final newData = {
          'b': FakeCipherMessage(),
          'c': FakeCipherMessage(),
          'e': FakeCipherMessage(),
          'f': FakeCipherMessage(),
        };

        when(() => mockSyncObjectStore.rawKeys).thenReturn(currentKeys);

        final result = sut
            .generateJobs(
              data: newData,
              conflictsTriggerUpload: true,
            )
            .toList();

        expect(result, hasLength(6));
        expect(result[0], isDeleteJob('a', mockSyncNode, isTrue));
        expect(result[1], isDeleteJob('d', mockSyncNode, isTrue));
        expect(
          result[2],
          isUpdateJob('b', same(newData['b']), mockSyncNode, isTrue),
        );
        expect(
          result[3],
          isUpdateJob('c', same(newData['c']), mockSyncNode, isTrue),
        );
        expect(
          result[4],
          isUpdateJob('e', same(newData['e']), mockSyncNode, isTrue),
        );
        expect(
          result[5],
          isUpdateJob('f', same(newData['f']), mockSyncNode, isTrue),
        );
      });
    });
  });
}
