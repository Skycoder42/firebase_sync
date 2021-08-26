import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/crypto/data_encryptor.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/sync_job_executor.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSyncJobExecutor extends Mock implements SyncJobExecutor {}

class MockDataEncryptor extends Mock implements DataEncryptor {}

class MockJsonConverter extends Mock implements JsonConverter<int> {}

class MockConflictResolver extends Mock implements ConflictResolver<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class MockCryptoFirebaseStore extends Mock implements CryptoFirebaseStore {}

class MockStreamSubscription extends Mock implements StreamSubscription<void> {}

void main() {
  group('SyncNode', () {
    final mockSyncJobExecutor = MockSyncJobExecutor();
    final mockDataEncryptor = MockDataEncryptor();
    final mockJsonConverter = MockJsonConverter();
    final mockConflictResolver = MockConflictResolver();
    final mockLocalStore = MockSyncObjectStore();
    final mockRemoteStore = MockCryptoFirebaseStore();
    final mockStreamSubscription = MockStreamSubscription();

    late SyncNode<int> sut;

    setUp(() {
      sut = SyncNode(
        storeName: '',
        syncJobExecutor: mockSyncJobExecutor,
        dataEncryptor: mockDataEncryptor,
        jsonConverter: mockJsonConverter,
        conflictResolver: mockConflictResolver,
        localStore: mockLocalStore,
        remoteStore: mockRemoteStore,
        errorSubscription: mockStreamSubscription,
      );
    });

    test('close cleans up all required components', () async {
      when(() => mockSyncJobExecutor.close()).thenAnswer((i) async {});
      when(() => mockStreamSubscription.cancel()).thenAnswer((i) async {});

      await sut.close();

      verify(() => mockSyncJobExecutor.close());
      verify(() => mockStreamSubscription.cancel());
      verify(() => mockDataEncryptor.dispose());
    });
  });
}
