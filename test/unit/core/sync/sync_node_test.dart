import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/crypto/data_encryptor.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/job_scheduler.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockJobScheduler extends Mock implements JobScheduler {}

class MockDataEncryptor extends Mock implements DataEncryptor {}

class MockJsonConverter extends Mock implements JsonConverter<int> {}

class MockConflictResolver extends Mock implements ConflictResolver<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class MockCryptoFirebaseStore extends Mock implements CryptoFirebaseStore {}

void main() {
  group('SyncNode', () {
    final mockJobScheduler = MockJobScheduler();
    final mockDataEncryptor = MockDataEncryptor();
    final mockJsonConverter = MockJsonConverter();
    final mockConflictResolver = MockConflictResolver();
    final mockLocalStore = MockSyncObjectStore();
    final mockRemoteStore = MockCryptoFirebaseStore();

    late SyncNode<int> sut;

    setUp(() {
      sut = SyncNode(
        storeName: '',
        jobScheduler: mockJobScheduler,
        dataEncryptor: mockDataEncryptor,
        jsonConverter: mockJsonConverter,
        conflictResolver: mockConflictResolver,
        localStore: mockLocalStore,
        remoteStore: mockRemoteStore,
      );
    });

    test('dispose calls dataEncryptor.dispose', () {
      sut.dispose();

      verify(() => mockDataEncryptor.dispose());
    });
  });
}
