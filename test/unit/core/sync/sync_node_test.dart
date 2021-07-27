import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/crypto/data_encryptor.dart';
import 'package:firebase_sync/src/core/crypto/key_hasher.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/job_scheduler.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

class MockJobScheduler extends Mock implements JobScheduler {}

class MockKeyHasher extends Mock implements KeyHasher {}

class MockDataEncryptor extends Mock implements DataEncryptor {}

class MockJsonConverter extends Mock implements JsonConverter<Object> {}

class MockConflictResolver extends Mock implements ConflictResolver<Object> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<Object> {}

class MockCryptoFirebaseStore extends Mock implements CryptoFirebaseStore {}

void main() {
  const storeName = 'store';
  final mockJobScheduler = MockJobScheduler();
  final mockKeyHasher = MockKeyHasher();
  final mockDataEncryptor = MockDataEncryptor();
  final mockJsonConverter = MockJsonConverter();
  final mockConflictResolver = MockConflictResolver();
  final mockSyncObjectStore = MockSyncObjectStore();
  final mockCryptoFirebaseStore = MockCryptoFirebaseStore();

  late SyncNode sut;

  setUp(() {
    reset(mockJobScheduler);
    reset(mockKeyHasher);
    reset(mockDataEncryptor);
    reset(mockJsonConverter);
    reset(mockConflictResolver);
    reset(mockSyncObjectStore);
    reset(mockCryptoFirebaseStore);
  });

  group('without keyhasher', () {
    setUp(() {
      sut = SyncNode(
        storeName: storeName,
        jobScheduler: mockJobScheduler,
        keyHasher: null,
        dataEncryptor: mockDataEncryptor,
        jsonConverter: mockJsonConverter,
        conflictResolver: mockConflictResolver,
        localStore: mockSyncObjectStore,
        remoteStore: mockCryptoFirebaseStore,
      );
    });

    test('hashKeys returns false', () {
      expect(sut.hashKeys, isFalse);
    });

    test('boundKeyHasher returns null', () {
      expect(sut.boundKeyHasher, isNull);
    });
  });

  group('with keyhasher', () {
    setUp(() {
      sut = SyncNode(
        storeName: storeName,
        jobScheduler: mockJobScheduler,
        keyHasher: mockKeyHasher,
        dataEncryptor: mockDataEncryptor,
        jsonConverter: mockJsonConverter,
        conflictResolver: mockConflictResolver,
        localStore: mockSyncObjectStore,
        remoteStore: mockCryptoFirebaseStore,
      );
    });

    test('hashKeys returns true', () {
      expect(sut.hashKeys, isTrue);
    });

    test('boundKeyHasher returns hasher bound to mock', () {
      const hashedKey = 'HASHED';
      when(
        () => mockKeyHasher.hashKey(
          storeName: any(named: 'storeName'),
          key: any(named: 'key'),
        ),
      ).thenReturn(hashedKey);

      final boundKeyHasher = sut.boundKeyHasher;

      expect(boundKeyHasher, isNotNull);

      const key = 'KEY';
      final result = boundKeyHasher!.hashKey(key);

      expect(result, hashedKey);
      verify(() => mockKeyHasher.hashKey(storeName: storeName, key: key));
    });
  });
}
