// ignore_for_file: invalid_use_of_protected_member
import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_all_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'matchers.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockCryptoFirebaseStore extends Mock implements CryptoFirebaseStore {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class FakeCipherMessage extends Fake implements CipherMessage {}

void main() {
  setUpAll(() {
    registerFallbackValue(Filter.key().build());
  });

  group('DownloadAllJob', () {
    final mockSyncNode = MockSyncNode();
    final mockCryptoFirebaseStore = MockCryptoFirebaseStore();
    final mockSyncObjectStore = MockSyncObjectStore();

    setUp(() {
      reset(mockSyncNode);
      reset(mockCryptoFirebaseStore);
      reset(mockSyncObjectStore);

      when(() => mockSyncNode.remoteStore).thenReturn(mockCryptoFirebaseStore);
      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);
      when(() => mockSyncObjectStore.rawKeys).thenReturn(const []);
    });

    DownloadAllJob<int> createSut([Filter? filter]) => DownloadAllJob<int>(
          syncNode: mockSyncNode,
          filter: filter,
          conflictsTriggerUpload: false, // TODO test true case
        );

    group('expandImpl', () {
      test('calls remoteStore.all if no filter was set', () async {
        when(() => mockCryptoFirebaseStore.all())
            .thenAnswer((i) async => const {});

        await expectLater(createSut().expandImpl(), emitsDone);

        verify(() => mockCryptoFirebaseStore.all());
      });

      test('calls remoteStore.query with given filter', () async {
        final filter = Filter.key().build();
        when(() => mockCryptoFirebaseStore.query(any()))
            .thenAnswer((i) async => const {});

        await expectLater(createSut(filter).expandImpl(), emitsDone);

        verify(() => mockCryptoFirebaseStore.query(filter));
      });

      test('returns list of download and update jobs', () {
        final newData = {
          'b': FakeCipherMessage(),
          'c': FakeCipherMessage(),
        };

        when(() => mockSyncObjectStore.rawKeys).thenReturn(['a', 'b']);
        when(() => mockCryptoFirebaseStore.all())
            .thenAnswer((i) async => newData);

        final stream = createSut().expandImpl();

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
