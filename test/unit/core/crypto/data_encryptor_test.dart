import 'package:firebase_sync/src/core/crypto/data_encryptor.dart';
import 'package:test/test.dart';

void main() {
  group('DecryptResult', () {
    test('default constructor throws when plainKey is used', () {
      const sut = DecryptResult(42);
      expect(
        () => sut.plainKey,
        throwsA(isA<StateError>()),
      );
    });

    test('withPlainKey constructor does not throw when plainKey is used', () {
      const sut = DecryptResult.withPlainKey(
        jsonData: 42,
        plainKey: 'key',
      );
      expect(
        () => sut.plainKey,
        isNot(throwsA(isA<StateError>())),
      );
    });
  });
}
