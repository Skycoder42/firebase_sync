// ignore_for_file: invalid_use_of_protected_member
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/jobs/reset_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'matchers.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class FakeCipherMessage extends Fake implements CipherMessage {}

void main() {
  group('ResetJob', () {
    final mockSyncObjectStore = MockSyncObjectStore();
    final mockSyncNode = MockSyncNode();

    setUp(() {
      reset(mockSyncObjectStore);
      reset(mockSyncObjectStore);

      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);
    });

    group('expandImpl', () {
      test('returns list of download and update jobs', () {
        final newData = {
          'b': FakeCipherMessage(),
          'c': FakeCipherMessage(),
        };
        final sut = ResetJob(
          syncNode: mockSyncNode,
          data: newData,
        );

        when(() => mockSyncObjectStore.rawKeys).thenReturn(['a', 'b']);

        final stream = sut.expandImpl();

        expect(
          stream,
          emitsInOrder(<dynamic>[
            isDeleteJob('a', mockSyncNode, isFalse),
            isUpdateJob('b', same(newData['b']), mockSyncNode, isFalse),
            isUpdateJob('c', same(newData['c']), mockSyncNode, isFalse),
            emitsDone,
          ]),
        );
      });
    });
  });
}
