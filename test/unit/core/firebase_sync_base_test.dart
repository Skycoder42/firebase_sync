// ignore_for_file: invalid_use_of_protected_member

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_database_rest/rest.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/crypto/data_encryptor.dart';
import 'package:firebase_sync/src/core/firebase_sync_base.dart';
import 'package:firebase_sync/src/core/offline_store.dart';
import 'package:firebase_sync/src/core/store/store.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/sync_error.dart';
import 'package:firebase_sync/src/core/sync/sync_job_executor.dart';
import 'package:firebase_sync/src/core/sync/sync_mode.dart';
import 'package:firebase_sync/src/core/sync_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFirebaseSyncBase extends Mock implements FirebaseSyncBase {}

class MockFirebaseStore extends Mock implements FirebaseStore<dynamic> {}

class MockRestApi extends Mock implements RestApi {}

class FakeSyncObjectStore extends Fake implements SyncObjectStore<int> {}

class FakeJsonConverter extends Fake implements JsonConverter<int> {}

class FakeDataEncryptor extends Fake implements DataEncryptor {}

class FakeConflictResolver extends Fake implements ConflictResolver<int> {}

class FakeStore extends Fake implements Store<int> {
  final StoreClosedFn? onClosed;

  FakeStore([this.onClosed]);

  @override
  Future<void> close() => Future.value();
}

class MockStore extends Mock implements Store<int> {}

class FakeSyncStore extends FakeStore implements SyncStore<int> {}

class FakeOfflineStore extends FakeStore implements OfflineStore<int> {}

class SutFirebaseSyncBase extends FirebaseSyncBase {
  final MockFirebaseSyncBase mock;

  SutFirebaseSyncBase(this.mock);

  @override
  FirebaseStore get rootStore => mock.rootStore;

  @override
  Future<OfflineStore<T>> openOfflineStore<T extends Object>({
    required String name,
    required dynamic storageConverter,
  }) =>
      mock.openOfflineStore(
        name: name,
        storageConverter: storageConverter,
      );

  @override
  Future<SyncStore<T>> openStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required dynamic storageConverter,
    SyncMode syncMode = SyncMode.sync,
    ConflictResolver<T>? conflictResolver,
  }) =>
      mock.openStore(
        name: name,
        jsonConverter: jsonConverter,
        storageConverter: storageConverter,
        syncMode: syncMode,
        conflictResolver: conflictResolver,
      );
}

void main() {
  group('FirebaseSyncBase', () {
    const storeName = 'test-store';

    final mockFirebaseStore = MockFirebaseStore();
    final mockRestApi = MockRestApi();
    final sutMock = MockFirebaseSyncBase();

    late FirebaseSyncBase sut;

    setUp(() {
      reset(mockFirebaseStore);
      reset(mockRestApi);
      reset(sutMock);

      when(() => sutMock.rootStore).thenReturn(mockFirebaseStore);
      when(() => mockFirebaseStore.restApi).thenReturn(mockRestApi);

      sut = SutFirebaseSyncBase(sutMock);
    });

    tearDown(() async {
      await sut.close();
    });

    group('createSyncNode', () {
      final fakeSyncObjectStore = FakeSyncObjectStore();
      final fakeJsonConverter = FakeJsonConverter();
      final fakeDataEncryptor = FakeDataEncryptor();
      final fakeConflictResolver = FakeConflictResolver();

      test('creates a sync node from the given data', () {
        const rootPaths = ['/root', 'a/b'];
        when(() => mockFirebaseStore.subPaths).thenReturn(rootPaths);

        final syncNode = sut.createSyncNode(
          storeName: storeName,
          localStore: fakeSyncObjectStore,
          jsonConverter: fakeJsonConverter,
          dataEncryptor: fakeDataEncryptor,
          conflictResolver: fakeConflictResolver,
        );

        expect(syncNode.storeName, storeName);
        expect(syncNode.syncJobExecutor, isA<SyncJobExecutor>());
        expect(syncNode.dataEncryptor, same(fakeDataEncryptor));
        expect(syncNode.jsonConverter, same(fakeJsonConverter));
        expect(syncNode.conflictResolver, same(fakeConflictResolver));
        expect(syncNode.localStore, same(fakeSyncObjectStore));
        expect(
          syncNode.remoteStore,
          isA<CryptoFirebaseStore>()
              .having(
            (s) => s.restApi,
            'restApi',
            same(mockRestApi),
          )
              .having(
            (s) => s.subPaths,
            'subPaths',
            const [...rootPaths, storeName],
          ),
        );
        expect(syncNode.errorSubscription, isNotNull);
      });

      test('uses the default conflict resolver if none is given', () {
        when(() => mockFirebaseStore.subPaths).thenReturn(const []);

        final syncNode = sut.createSyncNode(
          storeName: storeName,
          localStore: fakeSyncObjectStore,
          jsonConverter: fakeJsonConverter,
          dataEncryptor: fakeDataEncryptor,
        );

        expect(
          syncNode.conflictResolver,
          same(const ConflictResolver<Never>()),
        );
      });

      test('correctly registers to syncErrors of executor', () async {
        when(() => mockFirebaseStore.subPaths).thenReturn(const []);

        final syncNode = sut.createSyncNode(
          storeName: storeName,
          localStore: fakeSyncObjectStore,
          jsonConverter: fakeJsonConverter,
          dataEncryptor: fakeDataEncryptor,
          conflictResolver: fakeConflictResolver,
        );

        final error = Exception();
        final stackTrace = StackTrace.current;

        syncNode.syncJobExecutor.addError(error, stackTrace);

        await expectLater(
          sut.syncErrors,
          emits(
            SyncError.named(
              name: storeName,
              error: error,
              stackTrace: stackTrace,
            ),
          ),
        );

        await expectLater(syncNode.errorSubscription.cancel(), completes);

        syncNode.syncJobExecutor.addError(Exception());
      });
    });

    group('getAndCreateStore', () {
      test('getStore throws if no store is registered', () {
        expect(sut.isStoreOpen(storeName), isFalse);
        expect(() => sut.getStore(storeName), throwsA(isA<StateError>()));
      });

      test('createStore creates a new store', () async {
        final store = FakeStore();
        final result = await sut.createStore(storeName, (onClosed) => store);

        expect(sut.isStoreOpen(storeName), isTrue);
        expect(result, same(store));

        final getResult = sut.getStore(storeName);
        expect(getResult, same(store));
      });

      test('createStore throws if already created', () async {
        await sut.createStore(storeName, (onClosed) => FakeStore());
        expect(sut.isStoreOpen(storeName), isTrue);
        expect(
          () => sut.createStore(storeName, (onClosed) => FakeStore()),
          throwsA(isA<StateError>()),
        );
      });

      test('onClosed removes store from store list', () async {
        final store = await sut.createStore(
          storeName,
          (onClosed) => FakeStore(onClosed),
        );

        expect(sut.isStoreOpen(storeName), isTrue);
        expect(sut.getStore(storeName), same(store));

        store.onClosed!.call();

        expect(sut.isStoreOpen(storeName), isFalse);
        expect(() => sut.getStore(storeName), throwsA(isA<StateError>()));
      });

      test('getStore throws if type is wrong', () async {
        final store =
            await sut.createStore(storeName, (onClosed) => FakeStore());

        expect(sut.getStore(storeName), same(store));
        expect(sut.getStore<int, FakeStore>(storeName), same(store));
        expect(sut.getStore<int, Store<int>>(storeName), same(store));
        expect(sut.getStore<Object, Store<Object>>(storeName), same(store));
        expect(
          () => sut.getStore<String, Store<String>>(storeName),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('online', () {
      test('does not have store by default', () {
        expect(sut.isStoreOpen(storeName), isFalse);
        expect(() => sut.store(storeName), throwsA(isA<StateError>()));
      });

      test('returns store if it was created', () async {
        final store =
            await sut.createStore(storeName, (onClosed) => FakeSyncStore());

        expect(sut.isStoreOpen(storeName), isTrue);
        expect(sut.store(storeName), same(store));
      });

      test('throws if different store type was created', () async {
        await sut.createStore(storeName, (onClosed) => FakeOfflineStore());

        expect(sut.isStoreOpen(storeName), isTrue);
        expect(() => sut.store(storeName), throwsA(isA<StateError>()));
      });
    });

    group('offline', () {
      test('does not have store by default', () {
        expect(sut.isStoreOpen(storeName), isFalse);
        expect(() => sut.offlineStore(storeName), throwsA(isA<StateError>()));
      });

      test('returns store if it was created', () async {
        final store =
            await sut.createStore(storeName, (onClosed) => FakeOfflineStore());

        expect(sut.isStoreOpen(storeName), isTrue);
        expect(sut.offlineStore(storeName), same(store));
      });

      test('throws if different store type was created', () async {
        await sut.createStore(storeName, (onClosed) => FakeSyncStore());

        expect(sut.isStoreOpen(storeName), isTrue);
        expect(() => sut.offlineStore(storeName), throwsA(isA<StateError>()));
      });
    });

    test('close closes all open stores and error stream', () async {
      const storeName1 = 'storeName-1';
      const storeName2 = 'storeName-2';

      final mockStore1 = MockStore();
      final mockStore2 = MockStore();

      when(() => mockStore1.close())
          .thenAnswer((i) => Future.delayed(const Duration(milliseconds: 500)));
      when(() => mockStore2.close()).thenAnswer((i) async {});

      await sut.createStore(storeName1, (_) => mockStore1);
      await sut.createStore(storeName2, (_) => mockStore2);

      expect(sut.isStoreOpen(storeName1), isTrue);
      expect(sut.isStoreOpen(storeName2), isTrue);

      expect(sut.syncErrors, emitsDone);
      await expectLater(sut.close(), completes);

      expect(sut.isStoreOpen(storeName1), isFalse);
      expect(sut.isStoreOpen(storeName2), isFalse);

      verify(() => mockStore1.close());
      verify(() => mockStore2.close());
    });
  });
}
