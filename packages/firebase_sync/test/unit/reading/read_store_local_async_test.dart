import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/reading/read_only_store_async.dart';
import 'package:firebase_sync/src/reading/read_store_local_async.dart';
import 'package:firebase_sync/src/storage/storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_data.dart';

class MockFirebaseStore<T> extends Mock implements FirebaseStore<T> {}

class MockStorage<T extends Object> extends Mock implements Storage<T> {}

void main() {
  final mockFirebaseStore = MockFirebaseStore<int>();
  final mockStorage = MockStorage<int>();

  late ReadStoreLocalAsync<int> sut;

  setUp(() {
    reset(mockFirebaseStore);
    reset(mockStorage);

    when(() => mockStorage.isSync).thenReturn(false);

    sut = ReadOnlyStoreAsync(
      firebaseStore: mockFirebaseStore,
      storage: mockStorage,
    );
  });

  test('length returns storage.length()', () async {
    when(() => mockStorage.length()).thenAnswer((i) async => 42);

    expect(await sut.length(), 42);
    verify(() => mockStorage.length());
  });

  testData<Tuple2<int, bool>>(
    'isEmpty returns correct value for length',
    const [
      Tuple2(0, true),
      Tuple2(1, false),
    ],
    (fixture) async {
      when(() => mockStorage.length()).thenAnswer((i) async => fixture.item1);

      expect(await sut.isEmpty(), fixture.item2);
      verify(() => mockStorage.length());
    },
  );

  testData<Tuple2<int, bool>>(
    'isNotEmpty returns correct value for length',
    const [
      Tuple2(0, false),
      Tuple2(1, true),
    ],
    (fixture) async {
      when(() => mockStorage.length()).thenAnswer((i) async => fixture.item1);

      expect(await sut.isNotEmpty(), fixture.item2);
      verify(() => mockStorage.length());
    },
  );

  test('keys returns storage.keys()', () async {
    const keys = ['a', 'b', 'c'];
    when(() => mockStorage.keys()).thenAnswer((i) async => keys);

    expect(await sut.keys(), keys);
    verify(() => mockStorage.keys());
  });

  test('contains returns storage.contains()', () async {
    const key = 'key';
    when(() => mockStorage.contains(any())).thenAnswer((i) async => true);

    expect(await sut.contains(key), isTrue);
    verify(() => mockStorage.contains(key));
  });

  test('clear calls storage.clear()', () async {
    await sut.clear();

    verify(() => mockStorage.clear());
  });

  test('asMap returns storage.entries()', () async {
    const entries = <String, int>{
      'a': 1,
      'b': 2,
      'x': 3,
    };
    when(() => mockStorage.entries()).thenAnswer((i) async => entries);

    expect(await sut.asMap(), entries);
    verify(() => mockStorage.entries());
  });

  test('value returns storage.readEntry()', () async {
    const key = 'key';
    when(() => mockStorage.readEntry(any())).thenAnswer((i) async => 42);

    expect(await sut.value(key), 42);
    verify(() => mockStorage.readEntry(key));
  });

  test('watch returns storage.watch()', () {
    when(() => mockStorage.watch()).thenAnswer((i) => const Stream.empty());

    expect(sut.watch(), emitsDone);
    verify(() => mockStorage.watch());
  });

  test('watchEntry returns storage.watchEntry()', () {
    const key = 'key';
    when(() => mockStorage.watchEntry(any()))
        .thenAnswer((i) => const Stream.empty());

    expect(sut.watchEntry(key), emitsDone);
    verify(() => mockStorage.watchEntry(key));
  });
}
