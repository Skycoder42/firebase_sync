import 'package:firebase_sync/src/core/crypto/key_hasher.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockKeyHasher extends Mock implements KeyHasher {}

void main() {
  group('StoreBoundKeyHasher', () {
    const storeName = 'storeX';
    final mockKeyHash = MockKeyHasher();

    late StoreBoundKeyHasher sut;

    setUp(() {
      reset(mockKeyHash);

      sut = StoreBoundKeyHasher(
        storeName: storeName,
        keyHasher: mockKeyHash,
      );
    });

    test('hashKey calls keyHasher.hashKey', () {
      const expectedHash = 'hashed key';
      when(
        () => mockKeyHash.hashKey(
          storeName: any(named: 'storeName'),
          key: any(named: 'key'),
        ),
      ).thenReturn(expectedHash);

      const key = 'key';
      final result = sut.hashKey(key);

      expect(result, expectedHash);
      verify(() => mockKeyHash.hashKey(storeName: storeName, key: key));
    });
  });
}
