// ignore_for_file: invalid_use_of_protected_member

import 'package:firebase_sync/src/sodium/key_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sodium/src/api/secure_key.dart';
import 'package:test/test.dart';

class MockSecureKey extends Mock implements SecureKey {}

class MockPersistentKeySource extends Mock implements PersistentKeySource {}

class SutPersistentKeySource extends PersistentKeySource {
  final MockPersistentKeySource mock;

  SutPersistentKeySource(this.mock);

  @override
  Future<SecureKey?> restoreKey(KeyType keyType) => mock.restoreKey(keyType);

  @override
  Future<SecureKey> generateKey(KeyType keyType) => mock.generateKey(keyType);

  @override
  Future<void> persistKey(KeyType keyType, SecureKey key) =>
      mock.persistKey(keyType, key);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const KeyType.local(bytes: 0));
    registerFallbackValue(MockSecureKey());
  });

  group('PersistentKeySource', () {
    final sutMock = MockPersistentKeySource();

    late PersistentKeySource sut;

    setUp(() {
      reset(sutMock);

      sut = SutPersistentKeySource(sutMock);
    });

    group('obtainMasterKey', () {
      test('returns restored key if it exists', () async {
        final key = MockSecureKey();
        when(() => sutMock.restoreKey(any())).thenAnswer((i) async => key);

        const keyType = KeyType.local(bytes: 42);

        final result = await sut.obtainMasterKey(keyType);

        expect(result, same(key));
        verify(
          () => sutMock.restoreKey(keyType),
        );
      });

      test('creates, stores and returns key if it does not exist', () async {
        final key = MockSecureKey();
        when(() => sutMock.restoreKey(any())).thenAnswer((i) async => null);
        when(() => sutMock.generateKey(any())).thenAnswer((i) async => key);
        when(() => sutMock.persistKey(any(), any())).thenAnswer((i) async {});

        const keyType = KeyType.remote(
          bytes: 10,
          database: 'XXX',
          localId: 'my-id',
        );

        final result = await sut.obtainMasterKey(keyType);

        expect(result, same(key));
        verifyInOrder([
          () => sutMock.generateKey(keyType),
          () => sutMock.persistKey(keyType, key),
        ]);
      });

      test('disposes created key if persisting fails', () async {
        final key = MockSecureKey();
        when(() => sutMock.restoreKey(any())).thenAnswer((i) async => null);
        when(() => sutMock.generateKey(any())).thenAnswer((i) async => key);
        when(() => sutMock.persistKey(any(), any())).thenThrow(Exception());

        const keyType = KeyType.remote(
          bytes: 10,
          database: 'XXX',
          localId: 'my-id',
        );

        await expectLater(
          () => sut.obtainMasterKey(keyType),
          throwsA(isA<Exception>()),
        );
        verifyInOrder([
          () => sutMock.generateKey(keyType),
          () => sutMock.persistKey(keyType, key),
          () => key.dispose(),
        ]);
      });
    });
  });
}
