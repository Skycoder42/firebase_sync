import 'package:firebase_sync/firebase_sync.dart';
import 'package:test/test.dart';

void main() {
  group('ExtraArgInfo', () {
    const args = <String, dynamic>{
      't1': 1,
    };

    test('create creates info', () {
      final info = ExtraArgInfo.create<bool>(
        name: 't0',
        defaultValue: false,
        description: 'test',
      );

      expect(info.name, 't0');
      expect(info.type, bool);
      expect(info.defaultValue, false);
      expect(info.description, 'test');
    });

    test('Extracts arg', () {
      const info = ExtraArgInfo(name: 't1', type: int);
      expect(info.extractArg<int>(args), 1);
    });

    test('Extracts arg with default value', () {
      const info = ExtraArgInfo(name: 't2', type: int, defaultValue: 2);
      expect(info.extractArg<int>(args), 2);
    });

    test('allows null values', () {
      final info = ExtraArgInfo.create<int?>(name: 't3', defaultValue: null);
      expect(info.extractArg<int?>(args), null);
    });

    test('Asserts if T is different', () {
      const info = ExtraArgInfo(name: 't4', type: int);
      expect(() => info.extractArg<bool>(args), throwsA(isA<AssertionError>()));
    });
  });
}
