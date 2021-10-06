import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_sync/src/sodium/key_source.dart';
import 'package:firebase_sync/src/sodium/sodium_key_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sodium/sodium.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_data.dart';

class MockSodium extends Mock implements Sodium {}

class MockCrypto extends Mock implements Crypto {}

class MockKdf extends Mock implements Kdf {}

class MockKeySource extends Mock implements KeySource {}

class MockSecureKey extends Mock implements SecureKey {}

void main() {
  setUpAll(() {
    registerFallbackValue<SecureKey>(MockSecureKey());
    registerFallbackValue(const KeyType.local(bytes: 0));
  });

  group('SodiumKeyManager', () {
    const database = 'key-manager-test-database';
    const localId = 'key-manager-test-local-id';
    const lockTimeout = Duration(seconds: 20);

    final mockSodium = MockSodium();
    final mockCrypto = MockCrypto();
    final mockKdf = MockKdf();
    final mockKeySource = MockKeySource();

    late SodiumKeyManager sut;

    setUp(() {
      reset(mockSodium);
      reset(mockCrypto);
      reset(mockKdf);
      reset(mockKeySource);

      when(() => mockSodium.crypto).thenReturn(mockCrypto);
      when(() => mockCrypto.kdf).thenReturn(mockKdf);

      sut = SodiumKeyManager(
        sodium: mockSodium,
        keySource: mockKeySource,
        database: database,
        localId: localId,
        lockTimeout: lockTimeout,
        clock: clock,
      );
    });

    tearDown(() {
      sut.dispose();
    });

    test('defaultLockTimeout should be 10 seconds', () {
      expect(SodiumKeyManager.defaultLockTimeout, const Duration(seconds: 10));
    });

    testData<Tuple2<DateTime, int>>(
      'currentRemoteKeyId returns correct key id by date',
      [
        Tuple2(DateTime(2021, 9, 30), 629),
        // ignore: avoid_redundant_argument_values
        Tuple2(DateTime(2021, 10, 1), 630),
        Tuple2(DateTime(2021, 10, 30), 630),
        Tuple2(DateTime(2021, 10, 31), 631),
      ],
      (fixture) {
        sut = SodiumKeyManager(
          sodium: mockSodium,
          keySource: mockKeySource,
          database: database,
          localId: localId,
          lockTimeout: lockTimeout,
          clock: Clock.fixed(fixture.item1),
        );

        expect(sut.currentRemoteKeyId, fixture.item2);
      },
    );

    group('localEncryptionKey', () {
      const kdfKeyBytes = 256;
      final masterKey = MockSecureKey();
      final localEncryptionKey = MockSecureKey();

      setUp(() {
        reset(masterKey);

        when(() => mockKeySource.obtainMasterKey(any()))
            .thenAnswer((i) async => masterKey);

        when(() => mockKdf.keyBytes).thenReturn(kdfKeyBytes);
        when(
          () => mockKdf.deriveFromKey(
            masterKey: any(named: 'masterKey'),
            context: 'fbslocal',
            subkeyId: any(named: 'subkeyId'),
            subkeyLen: any(named: 'subkeyLen'),
          ),
        ).thenReturn(localEncryptionKey);
      });

      test('obtains masterkey and generate local key', () async {
        const storeId = 111;
        const localKeyBytes = 123;

        final key = await sut.localEncryptionKey(
          storeId: storeId,
          keyBytes: localKeyBytes,
        );

        expect(key, localEncryptionKey);

        verifyInOrder([
          () => mockKdf.keyBytes,
          () => mockKeySource.obtainMasterKey(
                const KeyType.local(
                  bytes: kdfKeyBytes,
                ),
              ),
          () => mockKdf.deriveFromKey(
                masterKey: masterKey,
                context: 'fbslocal',
                subkeyId: storeId,
                subkeyLen: localKeyBytes,
              ),
        ]);
      });

      test('uses cached local master key if available', () async {
        const storeId1 = 111;
        const storeId2 = 222;
        const localKeyBytes = 123;

        final key1 = await sut.localEncryptionKey(
          storeId: storeId1,
          keyBytes: localKeyBytes,
        );
        final key2 = await sut.localEncryptionKey(
          storeId: storeId2,
          keyBytes: localKeyBytes,
        );

        expect(key1, localEncryptionKey);
        expect(key2, localEncryptionKey);

        verify(() => mockKdf.keyBytes).called(1);
        verify(
          () => mockKeySource.obtainMasterKey(
            const KeyType.local(
              bytes: kdfKeyBytes,
            ),
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: masterKey,
            context: 'fbslocal',
            subkeyId: storeId1,
            subkeyLen: localKeyBytes,
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: masterKey,
            context: 'fbslocal',
            subkeyId: storeId2,
            subkeyLen: localKeyBytes,
          ),
        ).called(1);
      });

      test('clears local master key after timeout', () {
        const storeId1 = 77;
        const storeId2 = 88;
        const localKeyBytes = 123;

        fakeAsync((async) {
          expect(
            sut.localEncryptionKey(
              storeId: storeId1,
              keyBytes: localKeyBytes,
            ),
            completion(localEncryptionKey),
          );

          async.elapse(lockTimeout - const Duration(milliseconds: 10));

          verifyNever(() => masterKey.dispose());

          expect(
            sut.localEncryptionKey(
              storeId: storeId2,
              keyBytes: localKeyBytes,
            ),
            completion(localEncryptionKey),
          );

          async.elapse(const Duration(milliseconds: 10));

          verifyNever(() => masterKey.dispose());

          async.elapse(lockTimeout);

          verify(() => masterKey.dispose());
        });
      });

      test('resets timeout if keys are requested again', () {
        const storeId = 77;
        const localKeyBytes = 123;

        fakeAsync((async) {
          expect(
            sut.localEncryptionKey(
              storeId: storeId,
              keyBytes: localKeyBytes,
            ),
            completion(localEncryptionKey),
          );

          async.elapse(lockTimeout - const Duration(milliseconds: 10));

          verifyNever(() => masterKey.dispose());

          async.elapse(const Duration(milliseconds: 10));

          verify(() => masterKey.dispose());
        });
      });

      test('dispose clears all keys', () async {
        const storeId = 24;
        const remoteKeyBytes = 128;

        await expectLater(
          sut.localEncryptionKey(
            storeId: storeId,
            keyBytes: remoteKeyBytes,
          ),
          completion(localEncryptionKey),
        );

        verifyNever(() => masterKey.dispose());

        sut.dispose();

        verify(() => masterKey.dispose());

        sut.dispose();

        verifyNoMoreInteractions(masterKey);
      });
    });

    group('remoteEncryptionKey', () {
      const kdfKeyBytes = 256;
      final masterKey = MockSecureKey();
      final remoteEncryptionKey = MockSecureKey();
      final keyRotationKey = MockSecureKey();

      setUp(() {
        reset(masterKey);
        reset(remoteEncryptionKey);
        reset(keyRotationKey);

        when(() => mockKeySource.obtainMasterKey(any()))
            .thenAnswer((i) async => masterKey);

        when(() => mockKdf.keyBytes).thenReturn(kdfKeyBytes);
        when(
          () => mockKdf.deriveFromKey(
            masterKey: any(named: 'masterKey'),
            context: 'fbss_rot',
            subkeyId: any(named: 'subkeyId'),
            subkeyLen: any(named: 'subkeyLen'),
          ),
        ).thenReturn(keyRotationKey);
        when(
          () => mockKdf.deriveFromKey(
            masterKey: any(named: 'masterKey'),
            context: 'fbs_sync',
            subkeyId: any(named: 'subkeyId'),
            subkeyLen: any(named: 'subkeyLen'),
          ),
        ).thenReturn(remoteEncryptionKey);
      });

      test('obtains and generates all keys, returns final key', () async {
        const keyId = 42;
        const storeId = 24;
        const remoteKeyBytes = 128;

        final key = await sut.remoteEncryptionKey(
          keyId: keyId,
          storeId: storeId,
          keyBytes: remoteKeyBytes,
        );

        expect(key, remoteEncryptionKey);

        verifyInOrder([
          () => mockKdf.keyBytes,
          () => mockKeySource.obtainMasterKey(
                const KeyType.remote(
                  bytes: kdfKeyBytes,
                  database: database,
                  localId: localId,
                ),
              ),
          () => mockKdf.keyBytes,
          () => mockKdf.deriveFromKey(
                masterKey: masterKey,
                context: 'fbss_rot',
                subkeyId: keyId,
                subkeyLen: kdfKeyBytes,
              ),
          () => mockKdf.deriveFromKey(
                masterKey: keyRotationKey,
                context: 'fbs_sync',
                subkeyId: storeId,
                subkeyLen: remoteKeyBytes,
              ),
        ]);
      });

      test('only generates final key if others are cached', () async {
        const keyId = 42;
        const storeId1 = 24;
        const storeId2 = 25;
        const remoteKeyBytes = 128;

        final key1 = await sut.remoteEncryptionKey(
          keyId: keyId,
          storeId: storeId1,
          keyBytes: remoteKeyBytes,
        );

        final key2 = await sut.remoteEncryptionKey(
          keyId: keyId,
          storeId: storeId2,
          keyBytes: remoteKeyBytes,
        );

        expect(key1, remoteEncryptionKey);
        expect(key2, remoteEncryptionKey);

        verify(() => mockKdf.keyBytes).called(2);
        verify(
          () => mockKeySource.obtainMasterKey(
            const KeyType.remote(
              bytes: kdfKeyBytes,
              database: database,
              localId: localId,
            ),
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: masterKey,
            context: 'fbss_rot',
            subkeyId: keyId,
            subkeyLen: kdfKeyBytes,
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: keyRotationKey,
            context: 'fbs_sync',
            subkeyId: storeId1,
            subkeyLen: remoteKeyBytes,
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: keyRotationKey,
            context: 'fbs_sync',
            subkeyId: storeId2,
            subkeyLen: remoteKeyBytes,
          ),
        ).called(1);

        verifyNoMoreInteractions(mockKeySource);
        verifyNoMoreInteractions(mockKdf);
      });

      test('only generates rotation and final key if master key is cached',
          () async {
        const keyId1 = 42;
        const keyId2 = 43;
        const storeId = 24;
        const remoteKeyBytes = 128;

        final key1 = await sut.remoteEncryptionKey(
          keyId: keyId1,
          storeId: storeId,
          keyBytes: remoteKeyBytes,
        );

        final key2 = await sut.remoteEncryptionKey(
          keyId: keyId2,
          storeId: storeId,
          keyBytes: remoteKeyBytes,
        );

        expect(key1, remoteEncryptionKey);
        expect(key2, remoteEncryptionKey);

        verify(() => mockKdf.keyBytes).called(3);
        verify(
          () => mockKeySource.obtainMasterKey(
            const KeyType.remote(
              bytes: kdfKeyBytes,
              database: database,
              localId: localId,
            ),
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: masterKey,
            context: 'fbss_rot',
            subkeyId: keyId1,
            subkeyLen: kdfKeyBytes,
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: masterKey,
            context: 'fbss_rot',
            subkeyId: keyId2,
            subkeyLen: kdfKeyBytes,
          ),
        ).called(1);
        verify(
          () => mockKdf.deriveFromKey(
            masterKey: keyRotationKey,
            context: 'fbs_sync',
            subkeyId: storeId,
            subkeyLen: remoteKeyBytes,
          ),
        ).called(2);

        verifyNoMoreInteractions(mockKeySource);
        verifyNoMoreInteractions(mockKdf);
      });

      test('clears rotation and master keys after timeout', () {
        const keyId = 42;
        const storeId = 24;
        const remoteKeyBytes = 128;

        fakeAsync((async) {
          expect(
            sut.remoteEncryptionKey(
              keyId: keyId,
              storeId: storeId,
              keyBytes: remoteKeyBytes,
            ),
            completion(remoteEncryptionKey),
          );

          async.elapse(lockTimeout - const Duration(milliseconds: 10));

          verifyNever(() => masterKey.dispose());
          verifyNever(() => keyRotationKey.dispose());

          async.elapse(const Duration(milliseconds: 10));

          verify(() => masterKey.dispose());
          verify(() => keyRotationKey.dispose());
        });
      });

      test('resets timeout if keys are requested again', () {
        const keyId1 = 42;
        const keyId2 = 43;
        const storeId = 24;
        const remoteKeyBytes = 128;

        fakeAsync((async) {
          expect(
            sut.remoteEncryptionKey(
              keyId: keyId1,
              storeId: storeId,
              keyBytes: remoteKeyBytes,
            ),
            completion(remoteEncryptionKey),
          );

          async.elapse(lockTimeout - const Duration(milliseconds: 10));

          verifyNever(() => masterKey.dispose());
          verifyNever(() => keyRotationKey.dispose());

          expect(
            sut.remoteEncryptionKey(
              keyId: keyId2,
              storeId: storeId,
              keyBytes: remoteKeyBytes,
            ),
            completion(remoteEncryptionKey),
          );

          async.elapse(const Duration(milliseconds: 10));

          verifyNever(() => masterKey.dispose());
          verifyNever(() => keyRotationKey.dispose());

          async.elapse(lockTimeout);

          verify(() => masterKey.dispose());
          verify(() => keyRotationKey.dispose()).called(2);
        });
      });

      test('dispose clears all keys', () async {
        const keyId = 42;
        const storeId = 24;
        const remoteKeyBytes = 128;

        await expectLater(
          sut.remoteEncryptionKey(
            keyId: keyId,
            storeId: storeId,
            keyBytes: remoteKeyBytes,
          ),
          completion(remoteEncryptionKey),
        );

        verifyNever(() => masterKey.dispose());
        verifyNever(() => keyRotationKey.dispose());

        sut.dispose();

        verify(() => masterKey.dispose());
        verify(() => keyRotationKey.dispose());

        sut.dispose();

        verifyNoMoreInteractions(masterKey);
        verifyNoMoreInteractions(keyRotationKey);
      });
    });
  });
}
