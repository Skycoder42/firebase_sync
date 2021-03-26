import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/storage/json_storage.dart';
import 'package:firebase_sync/src/storage/local_store_event.dart';
import 'package:firebase_sync/src/storage/storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../fakes.dart';
import '../../test_data.dart';

class MockStorage extends Mock implements Storage {}

class MockJsonConverter extends Mock implements JsonConverter<int> {}

void main() {
  final mockRawStorage = MockStorage();
  final mockJsonConverter = MockJsonConverter();

  late JsonStorage<int> sut;

  const key = 'key';

  setUpAll(() {
    registerFallbackValue<TransactionFn<Object, Object?>>(
      FakeTransactionFn<Object, Object?>(null),
    );
  });

  setUp(() {
    reset(mockRawStorage);
    reset(mockJsonConverter);

    sut = JsonStorage(
      rawStorage: mockRawStorage,
      jsonConverter: mockJsonConverter,
    );
  });

  group('forwards calls to', () {
    test('isSync', () {
      when(() => mockRawStorage.isSync).thenReturn(true);
      final res = sut.isSync;
      expect(res, isTrue);
      verify(() => mockRawStorage.isSync);
    });

    test('length', () {
      when(() => mockRawStorage.length()).thenReturn(42);
      final res = sut.length();
      expect(res, 42);
      verify(() => mockRawStorage.length());
    });

    test('keys', () {
      const keys = ['a', 'b', 'c'];
      when(() => mockRawStorage.keys()).thenReturn(keys);
      final res = sut.keys();
      expect(res, keys);
      verify(() => mockRawStorage.keys());
    });

    test('contains', () {
      when(() => mockRawStorage.contains(any())).thenReturn(true);
      final res = sut.contains(key);
      expect(res, isTrue);
      verify(() => mockRawStorage.contains(key));
    });

    test('deleteEntry', () {
      sut.deleteEntry(key);
      verify(() => mockRawStorage.deleteEntry(key));
    });

    test('deleteEntries', () {
      const keys = ['a', 'b', 'c'];
      sut.deleteEntries(keys);
      verify(() => mockRawStorage.deleteEntries(keys));
    });

    test('clear', () {
      sut.clear();
      verify(() => mockRawStorage.clear());
    });

    test('destroy', () {
      sut.destroy();
      verify(() => mockRawStorage.destroy());
    });

    test('close', () async {
      when(() => mockRawStorage.close()).thenAnswer((i) => Future.value(null));

      await sut.close();
      verify(() => mockRawStorage.close());
    });
  });

  group('transforms calls to', () {
    setUp(() {
      when(() => mockJsonConverter.dataFromJson(any<dynamic>()))
          .thenAnswer((i) => (i.positionalArguments.first as int) * 2);
      when<dynamic>(() => mockJsonConverter.dataToJson(any()))
          .thenAnswer((i) => (i.positionalArguments.first as int) * 2);
    });

    test('entries', () {
      when(() => mockRawStorage.entries()).thenReturn(const <String, Object>{
        'a': 1,
        'b': 2,
        'c': 3,
      });

      final res = sut.entries();

      expect(res, const {'a': 2, 'b': 4, 'c': 6});

      verify(() => mockRawStorage.entries());
      verify(() => mockJsonConverter.dataFromJson(any<dynamic>())).called(3);
    });

    testData<Tuple2<int?, int?>>('readEntry', const [
      Tuple2(10, 20),
      Tuple2(null, null),
    ], (fixture) {
      when(() => mockRawStorage.readEntry(any())).thenReturn(fixture.item1);

      final res = sut.readEntry(key);

      expect(res, fixture.item2);

      verify(() => mockRawStorage.readEntry(key));
      if (fixture.item1 != null) {
        verify(() => mockJsonConverter.dataFromJson(fixture.item1));
      } else {
        verifyNever(() => mockJsonConverter.dataFromJson(any<dynamic>()));
      }
    });

    test('watch', () async {
      when(() => mockRawStorage.watch()).thenAnswer(
        (i) => Stream.fromIterable(const [
          LocalStoreEvent.update('a', 1),
          LocalStoreEvent.update('b', 2),
          LocalStoreEvent.delete('c'),
        ]),
      );

      final res = sut.watch();

      await expectLater(
        res,
        emitsInOrder(const <LocalStoreEvent<int>>[
          LocalStoreEvent.update('a', 2),
          LocalStoreEvent.update('b', 4),
          LocalStoreEvent.delete('c'),
        ]),
      );

      verify(() => mockRawStorage.watch());
      verify(() => mockJsonConverter.dataFromJson(any<dynamic>())).called(2);
    });

    test('watchEntry', () async {
      when(() => mockRawStorage.watchEntry(any()))
          .thenAnswer((i) => Stream.fromIterable(const [1, null, 3]));

      final res = sut.watchEntry(key);

      await expectLater(res, emitsInOrder(const <int?>[2, null, 6]));

      verify(() => mockRawStorage.watchEntry(key));
      verify(() => mockJsonConverter.dataFromJson(any<dynamic>())).called(2);
    });

    test('writeEntry', () {
      sut.writeEntry(key, 15);

      verify<dynamic>(() => mockJsonConverter.dataToJson(15));
      verify(() => mockRawStorage.writeEntry(key, 30));
    });

    test('writeEntries', () {
      sut.writeEntries({'a': 1, 'b': 2, 'c': 3});

      verify<dynamic>(() => mockJsonConverter.dataToJson(any())).called(3);
      verify(
        () => mockRawStorage.writeEntries(const <String, Object>{
          'a': 2,
          'b': 4,
          'c': 6,
        }),
      );
    });

    test('transaction', () {
      when(() => mockRawStorage.transaction(any())).thenReturn(11);
      final mockTransaction = MockStorage();

      final res = sut.transaction((storage) {
        expect(storage, isNot(same(sut)));
        expect(
          storage,
          isA<JsonStorage>()
              .having(
                (s) => s.rawStorage,
                'rawStorage',
                same(mockTransaction),
              )
              .having(
                (s) => s.jsonConverter,
                'jsonConverter',
                same(mockJsonConverter),
              ),
        );
        return 22;
      });
      expect(res, 11);

      final cb = verify(() => mockRawStorage.transaction(captureAny()))
          .captured
          .single as TransactionFn<Object, int>;
      final cbRes = cb(mockTransaction);
      expect(cbRes, 22);
    });
  });
}
