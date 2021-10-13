import 'package:firebase_sync/src/hive/box_extensions.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class MockBoxBase extends Mock implements BoxBase<int> {}

class MockUuid extends Mock implements Uuid {}

void main() {
  group('BoxBaseX', () {
    final mockUuid = MockUuid();

    final sutMock = MockBoxBase();

    setUp(() {
      reset(mockUuid);
      reset(sutMock);
    });

    test('generates key from uuid', () {
      const id = 'uuid';

      when(() => sutMock.containsKey(any<dynamic>())).thenReturn(false);
      when(() => mockUuid.v4()).thenReturn(id);

      final result = sutMock.generateKey(mockUuid);

      expect(result, id);

      verify(() => sutMock.containsKey(id));
    });

    test('loops until no conflict happens anymore', () {
      var ctr = 0;

      when(() => sutMock.containsKey(any<dynamic>()))
          .thenAnswer((i) => ctr != 5);
      when(() => mockUuid.v4()).thenAnswer((i) => 'uuid-${ctr++}');

      final result = sutMock.generateKey(mockUuid);

      expect(result, 'uuid-4');
      expect(ctr, 5);

      verify(() => sutMock.containsKey('uuid-0'));
      verify(() => sutMock.containsKey('uuid-1'));
      verify(() => sutMock.containsKey('uuid-2'));
      verify(() => sutMock.containsKey('uuid-3'));
      verify(() => sutMock.containsKey('uuid-4'));
      verifyNoMoreInteractions(sutMock);
    });
  });
}
