import 'dart:typed_data';

import 'package:firebase_sync/src/sodium/sodium_uuid_x.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sodium/sodium.dart';
import 'package:test/test.dart';

class MockSodium extends Mock implements Sodium {}

class MockRandombytes extends Mock implements Randombytes {}

void main() {
  group('SodiumUuidX', () {
    final mockSodium = MockSodium();
    final mockRandombytes = MockRandombytes();

    setUp(() {
      reset(mockSodium);
      reset(mockRandombytes);

      when(() => mockSodium.randombytes).thenReturn(mockRandombytes);
    });

    test('uuid creates a Uuid instance with randombytes randomness', () {
      when(() => mockRandombytes.buf(any())).thenAnswer(
        (i) => Uint8List.fromList(
          List.filled(i.positionalArguments[0] as int, 42),
        ),
      );

      final id = mockSodium.uuid.v4();

      expect(id, '2a2a2a2a-2a2a-4a2a-aa2a-2a2a2a2a2a2a');

      verify(() => mockRandombytes.buf(16));
    });
  });
}
