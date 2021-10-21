import 'package:firebase_sync/src/core/store/store_event.dart';
import 'package:firebase_sync/src/core/store/update_action.dart';
import 'package:firebase_sync/src/hive/hive_offline_store.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class MockBox extends Mock implements Box<int> {}

class MockUuid extends Mock implements Uuid {}

abstract class ICloseFn {
  void call();
}

class MockCloseFn extends Mock implements ICloseFn {}

void main() {
  group('HiveOfflineStore', () {
    final mockBox = MockBox();
    final mockUuid = MockUuid();
    final mockCloseFn = MockCloseFn();

    late HiveOfflineStore<int> sut;

    setUp(() {
      reset(mockBox);
      reset(mockUuid);
      reset(mockCloseFn);

      when(() => mockBox.put(any<dynamic>(), any())).thenAnswer((i) async {});
      when(() => mockBox.delete(any<dynamic>())).thenAnswer((i) async {});

      sut = HiveOfflineStore(
        rawBox: mockBox,
        uuid: mockUuid,
        onClosed: mockCloseFn,
      );
    });

    test('count returns box.length', () {
      const length = 20;

      when(() => mockBox.length).thenReturn(length);

      final result = sut.count();

      expect(result, length);

      verify(() => mockBox.length);
    });

    group('listKeys', () {
      test('returns box.keys', () {
        const keys = ['A', 'B', 'C'];

        when(() => mockBox.keys).thenReturn(keys);

        final result = sut.listKeys();

        expect(result, keys);

        verify(() => mockBox.keys);
      });

      test('throws for non string keys', () {
        const keys = ['A', 3, 'C'];

        when(() => mockBox.keys).thenReturn(keys);

        expect(
          () => sut.listKeys(),
          throwsA(isA<TypeError>()),
        );

        verify(() => mockBox.keys);
      });
    });

    group('listEntries', () {
      test('returns box.toMap', () {
        const entries = {
          'a': 1,
          'b': 2,
          'c': 3,
        };

        when(() => mockBox.toMap()).thenReturn(entries);

        final result = sut.listEntries();

        expect(result, entries);

        verify(() => mockBox.toMap());
      });

      test('throws for non string keys', () {
        const entries = {
          'a': 1,
          42: 2,
          'c': 3,
        };

        when(() => mockBox.toMap()).thenReturn(entries);

        expect(
          () => sut.listEntries(),
          throwsA(isA<TypeError>()),
        );

        verify(() => mockBox.toMap());
      });
    });

    test('contains returns box.containsKey', () {
      const key = 'test';

      when(() => mockBox.containsKey(any<dynamic>())).thenReturn(true);

      final result = sut.contains(key);

      expect(result, isTrue);

      verify(() => mockBox.containsKey(key));
    });

    test('get returns box.get', () {
      const key = 'test';
      const value = 42;

      when(() => mockBox.get(any<dynamic>())).thenReturn(value);

      final result = sut.get(key);

      expect(result, value);

      verify(() => mockBox.get(key));
    });

    test('create creates new key and store value with that key', () {
      const key = 'random-key';
      const value = 111;

      when(() => mockUuid.v4()).thenReturn(key);
      when(() => mockBox.containsKey(any<dynamic>())).thenReturn(false);

      final result = sut.create(value);

      expect(result, key);

      verifyInOrder([
        () => mockUuid.v4(),
        () => mockBox.containsKey(key),
        () => mockBox.put(key, value),
      ]);
    });

    test('put calls box.put', () {
      const key = 'key';
      const value = 5;

      sut.put(key, value);

      verify(() => mockBox.put(key, value));
    });

    group('update', () {
      const key = 'update-key';
      const oldValue = 24;

      setUp(() {
        when(() => mockBox.get(any<dynamic>())).thenReturn(oldValue);
      });

      test('none returns old value', () {
        final result = sut.update(key, (value) {
          expect(value, oldValue);
          return const UpdateAction.none();
        });

        expect(result, oldValue);

        verify(() => mockBox.get(key));
        verifyNoMoreInteractions(mockBox);
      });

      test('update replaces old value with new value', () {
        const newValue = 42;

        final result = sut.update(key, (value) {
          expect(value, oldValue);
          return const UpdateAction.update(newValue);
        });

        expect(result, newValue);

        verifyInOrder([
          () => mockBox.get(key),
          () => mockBox.put(key, newValue),
        ]);
        verifyNoMoreInteractions(mockBox);
      });

      test('delete deletes old value', () {
        final result = sut.update(key, (value) {
          expect(value, oldValue);
          return const UpdateAction.delete();
        });

        expect(result, isNull);

        verifyInOrder([
          () => mockBox.get(key),
          () => mockBox.delete(key),
        ]);
        verifyNoMoreInteractions(mockBox);
      });
    });

    test('delete calls box.delete', () {
      const key = 'del-key';

      sut.delete(key);

      verify(() => mockBox.delete(key));
    });

    group('watch', () {
      test('calls box.watch', () {
        when(() => mockBox.watch()).thenAnswer((i) => const Stream.empty());

        final stream = sut.watch();
        expect(stream, emitsDone);

        verify(() => mockBox.watch());
      });

      test('maps box events to store events', () {
        when(() => mockBox.watch()).thenAnswer(
          (i) => Stream.fromIterable([
            BoxEvent('key1', 1, false),
            BoxEvent('key2', 2, false),
            BoxEvent('key3', null, true),
            BoxEvent('key4', null, false),
            BoxEvent('key5', 5, true),
          ]),
        );

        final stream = sut.watch();
        expect(
          stream,
          emitsInOrder(<dynamic>[
            const StoreEvent(key: 'key1', value: 1),
            const StoreEvent(key: 'key2', value: 2),
            const StoreEvent<int>(key: 'key3', value: null),
            const StoreEvent<int>(key: 'key4', value: null),
            const StoreEvent(key: 'key5', value: 5),
            emitsDone,
          ]),
        );
      });

      test('emits error on failed conversions, but continues', () {
        when(() => mockBox.watch()).thenAnswer(
          (i) => Stream.fromIterable([
            BoxEvent('key1', 1, false),
            BoxEvent('key2', 'test', false),
            BoxEvent(3, 2, false),
            BoxEvent('key4', null, true),
          ]),
        );

        final stream = sut.watch();
        expect(
          stream,
          emitsInOrder(<dynamic>[
            const StoreEvent(key: 'key1', value: 1),
            emitsError(isA<TypeError>()),
            emitsError(isA<TypeError>()),
            const StoreEvent<int>(key: 'key4', value: null),
            emitsDone,
          ]),
        );
      });
    });

    test('clear calls box.clear', () {
      when(() => mockBox.clear()).thenAnswer((i) async => 0);

      sut.clear();

      verify(() => mockBox.clear());
    });

    test('isEmpty calls box.isEmpty', () {
      when(() => mockBox.isEmpty).thenReturn(true);

      expect(sut.isEmpty, isTrue);
      verify(() => mockBox.isEmpty);
    });

    test('isNotEmpty calls box.isNotEmpty', () {
      when(() => mockBox.isNotEmpty).thenReturn(true);

      expect(sut.isNotEmpty, isTrue);
      verify(() => mockBox.isNotEmpty);
    });

    test('isOpen calls box.isOpen', () {
      when(() => mockBox.isOpen).thenReturn(true);

      expect(sut.isOpen, isTrue);
      verify(() => mockBox.isOpen);
    });

    test('lazy calls box.lazy', () {
      when(() => mockBox.lazy).thenReturn(true);

      expect(sut.lazy, isTrue);
      verify(() => mockBox.lazy);
    });

    test('name calls box.name', () {
      const name = 'test-name';
      when(() => mockBox.name).thenReturn(name);

      expect(sut.name, name);
      verify(() => mockBox.name);
    });

    test('path calls box.path', () {
      const path = 'test-path';
      when(() => mockBox.path).thenReturn(path);

      expect(sut.path, path);
      verify(() => mockBox.path);
    });

    test('compact calls box.compact', () async {
      when(() => mockBox.compact()).thenAnswer((i) async {});

      await sut.compact();

      verify(() => mockBox.compact());
    });

    test('values calls box.values', () {
      const values = [1, 10, 100];
      when(() => mockBox.values).thenReturn(values);

      expect(sut.values, values);
      verify(() => mockBox.values);
    });

    test('valuesBetween calls box.valuesBetween', () {
      const startKey = 'start';
      const endKey = 'end';
      const values = [9, 10, 11];

      when(
        () => mockBox.valuesBetween(
          startKey: any<dynamic>(named: 'startKey'),
          endKey: any<dynamic>(named: 'endKey'),
        ),
      ).thenReturn(values);

      expect(
        sut.valuesBetween(
          startKey: startKey,
          endKey: endKey,
        ),
        values,
      );
      verify(() => mockBox.valuesBetween(startKey: startKey, endKey: endKey));
    });

    test('close calls box.close', () async {
      when(() => mockBox.close()).thenAnswer((i) async {});

      await sut.close();

      verify(() => mockBox.close());
    });

    test('destroy calls box.deleteFromDisk', () async {
      when(() => mockBox.deleteFromDisk()).thenAnswer((i) async {});

      await sut.destroy();

      verify(() => mockBox.deleteFromDisk());
    });
  });
}
