// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_sync/src/sodium/key_source.dart';
import 'package:firebase_sync/src/sodium/password_based_key_source_mixin.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sodium/sodium.dart';
import 'package:test/test.dart';

class MockSodium extends Mock implements Sodium {}

class MockCrypto extends Mock implements Crypto {}

class MockPwhash extends Mock implements Pwhash {}

class MockGenericHash extends Mock implements GenericHash {}

class FakeSecureKey extends Fake implements SecureKey {}

class MockPasswordBasedKeySourceMixin extends Mock
    implements PasswordBasedKeySourceMixin {}

class SutPasswordBasedKeySource extends PersistentKeySource
    with PasswordBasedKeySourceMixin {
  final MockPasswordBasedKeySourceMixin mock;
  @override
  final MockSodium sodium;

  bool overrideDerieveKey = false;

  SutPasswordBasedKeySource({
    required this.mock,
    required this.sodium,
  });

  @override
  Future<MasterKeyComponents> obtainMasterKeyComponents() =>
      mock.obtainMasterKeyComponents();

  @override
  Future<void> persistKey(KeyType keyType, SecureKey key) =>
      mock.persistKey(keyType, key);

  @override
  Future<SecureKey?> restoreKey(KeyType keyType) => mock.restoreKey(keyType);

  @override
  Future<SecureKey> derieveKey(MasterKeyRequest masterKeyRequest) =>
      overrideDerieveKey
          ? mock.derieveKey(masterKeyRequest)
          : super.derieveKey(masterKeyRequest);
}

void main() {
  setUpAll(() {
    registerFallbackValue(Int8List(0));
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const MasterKeyRequest.internal(
        components: MasterKeyComponents(password: ''),
        keyType: RemoteKeyType(
          bytes: 0,
          database: '',
          localId: '',
        ),
      ),
    );
  });

  Matcher isSaltData({required String database, required String localId}) =>
      predicate<Uint8List>(
        (jsonData) {
          final decoded = json.decode(jsonData.signedView().toDartString())
              as Map<String, dynamic>;
          expect(decoded, hasLength(2));
          expect(decoded, containsPair('database', database));
          expect(decoded, containsPair('localId', localId));
          return true;
        },
      );

  group('PasswordBasedKeySourceMixin', () {
    final mockSodium = MockSodium();
    final mockCrypto = MockCrypto();
    final mockPwhash = MockPwhash();
    final mockGenericHash = MockGenericHash();

    setUp(() {
      reset(mockSodium);
      reset(mockCrypto);
      reset(mockPwhash);
      reset(mockGenericHash);

      when(() => mockSodium.crypto).thenReturn(mockCrypto);
      when(() => mockCrypto.pwhash).thenReturn(mockPwhash);
      when(() => mockCrypto.genericHash).thenReturn(mockGenericHash);
    });

    group('static', () {
      group('computeMasterKey', () {
        test('calls pwhash with all arguments', () {
          final salt = List.generate(10, (index) => index);
          final key = FakeSecureKey();

          const bytes = 32;
          const memLimit = 111;
          const opsLimit = 222;
          const password = 'password';
          const database = 'database';
          const localId = 'localId';

          when(
            () => mockGenericHash.call(
              outLen: any(named: 'outLen'),
              message: any(named: 'message'),
            ),
          ).thenReturn(Uint8List.fromList(salt));
          when(() => mockPwhash.saltBytes).thenReturn(salt.length);
          when(
            () => mockPwhash.call(
              outLen: any(named: 'outLen'),
              password: any(named: 'password'),
              salt: any(named: 'salt'),
              opsLimit: any(named: 'opsLimit'),
              memLimit: any(named: 'memLimit'),
            ),
          ).thenReturn(key);

          final result = PasswordBasedKeySourceMixin.computeMasterKey(
            mockSodium,
            const MasterKeyRequest.internal(
              components: MasterKeyComponents(
                password: password,
                memLimit: memLimit,
                opsLimit: opsLimit,
              ),
              keyType: RemoteKeyType(
                bytes: bytes,
                database: database,
                localId: localId,
              ),
            ),
          );

          expect(result, same(key));

          verifyInOrder([
            () => mockGenericHash.call(
                  outLen: salt.length,
                  message: any(
                    named: 'message',
                    that: isSaltData(database: database, localId: localId),
                  ),
                ),
            () => mockPwhash.call(
                  outLen: bytes,
                  password: password.toCharArray(),
                  salt: Uint8List.fromList(salt),
                  opsLimit: opsLimit,
                  memLimit: memLimit,
                ),
          ]);
        });

        test('calls pwhash with default arguments', () {
          final salt = List.generate(20, (index) => index);
          final key = FakeSecureKey();

          const bytes = 23;
          const memLimit = 321;
          const opsLimit = 123;
          const password = 'password3';
          const database = 'database2';
          const localId = 'localId1';

          when(
            () => mockGenericHash.call(
              outLen: any(named: 'outLen'),
              message: any(named: 'message'),
            ),
          ).thenReturn(Uint8List.fromList(salt));
          when(() => mockPwhash.saltBytes).thenReturn(salt.length);
          when(() => mockPwhash.opsLimitSensitive).thenReturn(opsLimit);
          when(() => mockPwhash.memLimitSensitive).thenReturn(memLimit);
          when(
            () => mockPwhash.call(
              outLen: any(named: 'outLen'),
              password: any(named: 'password'),
              salt: any(named: 'salt'),
              opsLimit: any(named: 'opsLimit'),
              memLimit: any(named: 'memLimit'),
            ),
          ).thenReturn(key);

          final result = PasswordBasedKeySourceMixin.computeMasterKey(
            mockSodium,
            const MasterKeyRequest.internal(
              components: MasterKeyComponents(
                password: password,
              ),
              keyType: RemoteKeyType(
                bytes: bytes,
                database: database,
                localId: localId,
              ),
            ),
          );

          expect(result, same(key));

          verifyInOrder([
            () => mockGenericHash.call(
                  outLen: salt.length,
                  message: any(
                    named: 'message',
                    that: isSaltData(database: database, localId: localId),
                  ),
                ),
            () => mockPwhash.opsLimitSensitive,
            () => mockPwhash.memLimitSensitive,
            () => mockPwhash.call(
                  outLen: bytes,
                  password: password.toCharArray(),
                  salt: Uint8List.fromList(salt),
                  opsLimit: opsLimit,
                  memLimit: memLimit,
                ),
          ]);
        });
      });
    });

    group('instance', () {
      final sutMock = MockPasswordBasedKeySourceMixin();

      late SutPasswordBasedKeySource sut;

      setUp(() {
        reset(sutMock);

        sut = SutPasswordBasedKeySource(
          mock: sutMock,
          sodium: mockSodium,
        );
      });

      group('generateKey', () {
        test('local generates random keys', () async {
          const bytes = 42;
          final randomKey = FakeSecureKey();

          when(() => mockSodium.secureRandom(any())).thenReturn(randomKey);

          final result =
              await sut.generateKey(const KeyType.local(bytes: bytes));

          expect(result, same(randomKey));

          verify(() => mockSodium.secureRandom(bytes));
        });

        group('remote', () {
          test('generates password based remote key', () async {
            const bytes = 44;
            const database = 'db';
            const localId = 'id';
            const masterKeyComponents = MasterKeyComponents(
              password: 'pw',
              memLimit: 10,
              opsLimit: 20,
            );

            final salt = Uint8List.fromList(List.filled(10, 10));
            final key = FakeSecureKey();

            when(() => sutMock.obtainMasterKeyComponents())
                .thenAnswer((i) async => masterKeyComponents);
            when(() => mockPwhash.saltBytes).thenReturn(salt.length);
            when(
              () => mockGenericHash.call(
                message: any(named: 'message'),
                outLen: any(named: 'outLen'),
              ),
            ).thenReturn(salt);
            when(
              () => mockPwhash.call(
                outLen: any(named: 'outLen'),
                password: any(named: 'password'),
                salt: any(named: 'salt'),
                opsLimit: any(named: 'opsLimit'),
                memLimit: any(named: 'memLimit'),
              ),
            ).thenReturn(key);

            final result = await sut.generateKey(
              const KeyType.remote(
                bytes: bytes,
                database: database,
                localId: localId,
              ),
            );

            expect(result, same(key));

            verifyInOrder([
              () => sutMock.obtainMasterKeyComponents(),
              () => mockGenericHash.call(
                    message: any(
                      named: 'message',
                      that: isSaltData(database: database, localId: localId),
                    ),
                    outLen: salt.length,
                  ),
              () => mockPwhash.call(
                    outLen: bytes,
                    password: masterKeyComponents.password.toCharArray(),
                    salt: Uint8List.fromList(salt),
                    opsLimit: masterKeyComponents.opsLimit!,
                    memLimit: masterKeyComponents.memLimit!,
                  ),
            ]);
          });

          test('uses custom overridden derieveKey method', () async {
            const keyType = KeyType.remote(
              bytes: 51,
              database: 'database',
              localId: 'localId',
            );
            const masterKeyComponents = MasterKeyComponents(
              password: 'pw',
              memLimit: 10,
              opsLimit: 20,
            );

            final key = FakeSecureKey();

            when(() => sutMock.obtainMasterKeyComponents())
                .thenAnswer((i) async => masterKeyComponents);
            when(() => sutMock.derieveKey(any())).thenAnswer((i) async => key);

            sut.overrideDerieveKey = true;
            final result = await sut.generateKey(keyType);

            expect(result, same(key));

            verifyInOrder([
              () => sutMock.obtainMasterKeyComponents(),
              () => sutMock.derieveKey(
                    const MasterKeyRequest.internal(
                      components: masterKeyComponents,
                      keyType: keyType as RemoteKeyType,
                    ),
                  ),
            ]);
          });
        });
      });
    });
  });
}
