import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/reading/read_only_store_async.dart';
import 'package:firebase_sync/src/reading/read_store_remote.dart';
import 'package:firebase_sync/src/storage/storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fakes.dart';

part 'read_store_remote_test.freezed.dart';

class MockFirebaseStore<T> extends Mock implements FirebaseStore<T> {}

class MockStorage<T extends Object> extends Mock implements Storage<T> {
  @override
  FutureOr<TR> transaction<TR>(TransactionFn<T, TR> transactionCallback) {
    super.noSuchMethod(Invocation.method(#transaction, [transactionCallback]));
    return transactionCallback(this);
  }
}

class MockPatchSet<T> extends Mock implements PatchSet<T> {}

@freezed
class TestObject with _$TestObject {
  const factory TestObject(int id, [String? data]) = _TestObject;
}

class Sut extends ReadOnlyStoreAsync<TestObject> {
  final List<String> invalidPaths = [];

  Sut({
    required FirebaseStore<TestObject> firebaseStore,
    required Storage<TestObject> storage,
  }) : super(
          firebaseStore: firebaseStore,
          storage: storage,
        );

  @override
  void onInvalidPath(String path) {
    invalidPaths.add(path);
  }
}

void main() {
  final mockFirebaseStore = MockFirebaseStore<TestObject>();
  final mockStorage = MockStorage<TestObject>();

  late Sut _sut;
  late ReadStoreRemote<TestObject> sut;

  setUpAll(() {
    registerFakes();
    registerFallbackValue<TransactionFn<TestObject, Object?>>(
      FakeTransactionFn(null),
    );
    registerFallbackValue(const TestObject(-1));
  });

  setUp(() {
    reset(mockFirebaseStore);
    reset(mockStorage);

    when(() => mockStorage.isSync).thenReturn(false);

    _sut = Sut(
      firebaseStore: mockFirebaseStore,
      storage: mockStorage,
    );
    sut = _sut;
  });

  group('reload', () {
    group('ReloadStrategy.clear', () {
      setUp(() {
        _sut.reloadStrategy = ReloadStrategy.clear;
      });

      test('all', () async {
        const entries = {
          'a': TestObject(1),
          'b': TestObject(2),
        };
        when(() => mockFirebaseStore.all()).thenAnswer((i) async => entries);

        await sut.reload();

        verifyInOrder([
          () => mockFirebaseStore.all(),
          () => mockStorage.transaction(any()),
          () => mockStorage.clear(),
          () => mockStorage.writeEntries(entries),
        ]);
      });

      test('filtered', () async {
        const entries = {
          'a': TestObject(1),
          'b': TestObject(2),
        };
        when(() => mockFirebaseStore.query(any()))
            .thenAnswer((i) async => entries);

        final filter = Filter.key().build();
        await sut.reload(filter);

        verifyInOrder([
          () => mockFirebaseStore.query(filter),
          () => mockStorage.transaction(any()),
          () => mockStorage.clear(),
          () => mockStorage.writeEntries(entries),
        ]);
      });
    });

    group('ReloadStrategy.compareKey', () {
      setUp(() {
        _sut.reloadStrategy = ReloadStrategy.compareKey;
      });

      test('all', () async {
        const entries = {
          'a': TestObject(1),
          'b': TestObject(2),
        };
        when(() => mockFirebaseStore.all()).thenAnswer((i) async => entries);
        when(() => mockStorage.keys()).thenAnswer((i) async => ['a', 'c']);

        await sut.reload();

        verifyInOrder([
          () => mockFirebaseStore.all(),
          () => mockStorage.transaction(any()),
          () => mockStorage.keys(),
          () => mockStorage.writeEntries(entries),
          () => mockStorage.deleteEntries(const ['c']),
        ]);
      });

      test('filtered', () async {
        const entries = {
          'a': TestObject(1),
          'b': TestObject(2),
        };
        when(() => mockFirebaseStore.query(any()))
            .thenAnswer((i) async => entries);
        when(() => mockStorage.keys()).thenAnswer((i) async => ['a', 'c']);

        final filter = Filter.key().build();
        await sut.reload(filter);

        verifyInOrder([
          () => mockFirebaseStore.query(filter),
          () => mockStorage.transaction(any()),
          () => mockStorage.keys(),
          () => mockStorage.writeEntries(entries),
          () => mockStorage.deleteEntries(const ['c']),
        ]);
      });
    });

    group('ReloadStrategy.compareValue', () {
      setUp(() {
        _sut.reloadStrategy = ReloadStrategy.compareValue;
      });

      test('all', () async {
        when(() => mockFirebaseStore.all()).thenAnswer((i) async => const {
              'a': TestObject(1),
              'b': TestObject(2),
              'c': TestObject(3),
            });
        when(() => mockStorage.keys()).thenAnswer((i) async => ['a', 'b', 'd']);
        when(() => mockStorage.readEntry('a'))
            .thenAnswer((i) async => const TestObject(1));
        when(() => mockStorage.readEntry('b'))
            .thenAnswer((i) async => const TestObject(20));

        await sut.reload();

        verifyInOrder([
          () => mockFirebaseStore.all(),
          () => mockStorage.transaction(any()),
          () => mockStorage.keys(),
          () => mockStorage.writeEntries(const {
                'b': TestObject(2),
                'c': TestObject(3),
              }),
          () => mockStorage.deleteEntries(const ['d']),
        ]);
      });

      test('filtered', () async {
        when(() => mockFirebaseStore.query(any()))
            .thenAnswer((i) async => const {
                  'a': TestObject(1),
                  'b': TestObject(2),
                  'c': TestObject(3),
                });
        when(() => mockStorage.keys()).thenAnswer((i) async => ['a', 'b', 'd']);
        when(() => mockStorage.readEntry('a'))
            .thenAnswer((i) async => const TestObject(1));
        when(() => mockStorage.readEntry('b'))
            .thenAnswer((i) async => const TestObject(20));

        final filter = Filter.key().build();
        await sut.reload(filter);

        verifyInOrder([
          () => mockFirebaseStore.query(filter),
          () => mockStorage.transaction(any()),
          () => mockStorage.keys(),
          () => mockStorage.writeEntries(const {
                'b': TestObject(2),
                'c': TestObject(3),
              }),
          () => mockStorage.deleteEntries(const ['d']),
        ]);
      });
    });
  });

  group('sync', () {
    test('streams all without a filter', () async {
      when(() => mockFirebaseStore.streamAll())
          .thenAnswer((i) async => const Stream.empty());

      final sub = await sut.sync();
      await sub.cancel();

      verify(() => mockFirebaseStore.streamAll());
    });

    test('streams query with a filter', () async {
      when(() => mockFirebaseStore.streamQuery(any()))
          .thenAnswer((i) async => const Stream.empty());

      final filter = Filter.key().build();
      final sub = await sut.sync(filter: filter);
      await sub.cancel();

      verify(() => mockFirebaseStore.streamQuery(filter));
    });

    test('forwards done event', () async {
      when(() => mockFirebaseStore.streamAll())
          .thenAnswer((i) async => const Stream.empty());

      final completer = Completer<void>();
      final sub = await sut.sync(onDone: () => completer.complete());
      try {
        await expectLater(completer.future, completes);
      } finally {
        await sub.cancel();
      }
    });

    test('forwards error events', () async {
      when(() => mockFirebaseStore.streamAll())
          .thenAnswer((i) async => Stream.error(Exception('error')));

      final completer = Completer<Object>();
      final sub = await sut.sync(
        onError: (Object error) => completer.complete(error),
      );
      try {
        await expectLater(completer.future, completion(isA<Exception>()));
      } finally {
        await sub.cancel();
      }
    });

    group('stream events', () {
      test('resets store on reset event', () async {
        const entries = {
          'a': TestObject(1),
          'b': TestObject(2),
        };

        when(() => mockFirebaseStore.streamAll()).thenAnswer(
          (i) async => Stream.value(const StoreEvent.reset(entries)),
        );

        _sut.reloadStrategy = ReloadStrategy.clear;
        final sub = await sut.sync();
        try {
          await sub.asFuture<void>();
          verifyInOrder([
            () => mockFirebaseStore.streamAll(),
            () => mockStorage.transaction(any()),
            () => mockStorage.clear(),
            () => mockStorage.writeEntries(entries),
          ]);
        } finally {
          await sub.cancel();
        }
      });

      test('put replaces entry in store', () async {
        const key = 'key';
        const data = TestObject(10);

        when(() => mockFirebaseStore.streamAll()).thenAnswer(
          (i) async => Stream.value(const StoreEvent.put(key, data)),
        );

        final sub = await sut.sync();
        try {
          await sub.asFuture<void>();
          verifyInOrder([
            () => mockFirebaseStore.streamAll(),
            () => mockStorage.writeEntry(key, data),
          ]);
        } finally {
          await sub.cancel();
        }
      });

      test('delete removes entry from store', () async {
        const key = 'key';

        when(() => mockFirebaseStore.streamAll()).thenAnswer(
          (i) async => Stream.value(const StoreEvent.delete(key)),
        );

        final sub = await sut.sync();
        try {
          await sub.asFuture<void>();
          verifyInOrder([
            () => mockFirebaseStore.streamAll(),
            () => mockStorage.deleteEntry(key),
          ]);
        } finally {
          await sub.cancel();
        }
      });

      test('patch updates entry in store', () async {
        const key = 'key';
        const data1 = TestObject(20);
        const data2 = TestObject(30);
        final mockPatchSet = MockPatchSet<TestObject>();

        when(() => mockFirebaseStore.streamAll()).thenAnswer(
          (i) async => Stream.value(StoreEvent.patch(key, mockPatchSet)),
        );
        when(() => mockStorage.readEntry(any())).thenAnswer((i) async => data1);
        when(() => mockPatchSet.apply(any())).thenReturn(data2);

        final sub = await sut.sync();
        try {
          await sub.asFuture<void>();
          verifyInOrder([
            () => mockFirebaseStore.streamAll(),
            () => mockStorage.readEntry(key),
            () => mockPatchSet.apply(data1),
            () => mockStorage.writeEntry(key, data2),
          ]);
        } finally {
          await sub.cancel();
        }
      });

      test('correctly reports invalid paths', () async {
        const path = 'path';

        when(() => mockFirebaseStore.streamAll()).thenAnswer(
          (i) async => Stream.value(const StoreEvent.invalidPath(path)),
        );

        final sub = await sut.sync();
        try {
          await sub.asFuture<void>();
          verify(() => mockFirebaseStore.streamAll());
          expect(_sut.invalidPaths, contains(path));
        } finally {
          await sub.cancel();
        }
      });

      test('events trigger the updated callback', () async {
        const key = 'key';

        when(() => mockFirebaseStore.streamAll()).thenAnswer(
          (i) async => Stream.value(const StoreEvent.delete(key)),
        );

        final completer = Completer<void>();
        final sub = await sut.sync(
          onUpdate: () => completer.complete(),
        );
        try {
          await expectLater(completer.future, completes);
          verify(() => mockFirebaseStore.streamAll());
        } finally {
          await sub.cancel();
        }
      });
    });
  });
}
