import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/sodium/sodium_data_encryptor.dart';
import 'package:firebase_sync/src/sodium/sodium_key_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sodium/sodium.dart';
import 'package:test/test.dart';

class MockSodium extends Mock implements Sodium {}

class MockCrypto extends Mock implements Crypto {}

class MockAead extends Mock implements Aead {}

class MockRandombytes extends Mock implements Randombytes {}

class MockSodiumKeyManager extends Mock implements SodiumKeyManager {}

class FakeSecureKey extends Fake implements SecureKey {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(FakeSecureKey());
  });

  group('SodiumDataEncryptor', () {
    const storeId = 42;
    final remoteUri = Uri(
      scheme: 'test',
      host: 'test-host',
      path: '/test/path',
    );

    final mockSodium = MockSodium();
    final mockCrypto = MockCrypto();
    final mockAead = MockAead();
    final mockRandombytes = MockRandombytes();
    final mockSodiumKeyManager = MockSodiumKeyManager();

    late SodiumDataEncryptor sut;

    Matcher isRemoteUri(List<int> expectedRemoteTag) =>
        predicate<Uint8List>((bytes) {
          final str = utf8.decode(bytes);
          final parsedUri = Uri.parse(str);
          final parsedBaseUri = parsedUri.removeFragment();
          expect(parsedBaseUri, equals(remoteUri));
          expect(
            parsedUri.fragment,
            base64.encode(expectedRemoteTag),
          );
          return true;
        });

    setUp(() {
      reset(mockSodium);
      reset(mockCrypto);
      reset(mockAead);
      reset(mockRandombytes);
      reset(mockSodiumKeyManager);

      when(() => mockSodium.crypto).thenReturn(mockCrypto);
      when(() => mockCrypto.aead).thenReturn(mockAead);
      when(() => mockSodium.randombytes).thenReturn(mockRandombytes);

      sut = SodiumDataEncryptor(
        storeId: storeId,
        sodium: mockSodium,
        keyManager: mockSodiumKeyManager,
      );
    });

    group('encrypt', () {
      test('correctly encrypts and returns cipher data', () async {
        const currentKeyId = 111;
        const aeadKeyBytes = 10;
        const aeadNonceBytes = 15;
        final encryptionKey = FakeSecureKey();
        final cryptoResult = DetachedCipherResult(
          cipherText: Uint8List.fromList(List.filled(9, 9)),
          mac: Uint8List.fromList(List.filled(18, 18)),
        );

        const testJson = {
          'a': true,
          'b': [1, 1.2, '123'],
        };

        when(() => mockSodiumKeyManager.currentRemoteKeyId)
            .thenReturn(currentKeyId);
        when(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: any(named: 'keyId'),
            storeId: any(named: 'storeId'),
            keyBytes: any(named: 'keyBytes'),
          ),
        ).thenAnswer((i) async => encryptionKey);

        when(() => mockAead.keyBytes).thenReturn(aeadKeyBytes);
        when(() => mockAead.nonceBytes).thenReturn(aeadNonceBytes);
        when(
          () => mockAead.encryptDetached(
            message: any(named: 'message'),
            additionalData: any(named: 'additionalData'),
            nonce: any(named: 'nonce'),
            key: any(named: 'key'),
          ),
        ).thenReturn(cryptoResult);

        when(() => mockRandombytes.buf(any())).thenAnswer(
          (i) => Uint8List.fromList(
            List.filled(i.positionalArguments.first as int, 10),
          ),
        );

        final result = await sut.encrypt(
          remoteUri: remoteUri,
          dataJson: testJson,
        );

        final expectedNonce = Uint8List.fromList(
          List.filled(aeadNonceBytes, 10),
        );
        final expectedRemoteTag = Uint8List.fromList(
          List.filled(CipherMessage.remoteTagSize, 10),
        );
        expect(
          result,
          CipherMessage(
            cipherText: cryptoResult.cipherText,
            mac: cryptoResult.mac,
            nonce: expectedNonce,
            remoteTag: expectedRemoteTag,
            keyId: currentKeyId,
          ),
        );

        verifyInOrder([
          () => mockSodiumKeyManager.currentRemoteKeyId,
          () => mockAead.keyBytes,
          () => mockSodiumKeyManager.remoteEncryptionKey(
                keyId: currentKeyId,
                storeId: storeId,
                keyBytes: aeadKeyBytes,
              ),
          () => mockRandombytes.buf(aeadNonceBytes),
          () => mockRandombytes.buf(CipherMessage.remoteTagSize),
          () => mockAead.encryptDetached(
                message: any(
                  named: 'message',
                  that: predicate<Uint8List>((bytes) {
                    final str = utf8.decode(bytes);
                    final dynamic decoded = json.decode(str);
                    expect(decoded, equals(testJson));
                    return true;
                  }),
                ),
                additionalData: any(
                  named: 'additionalData',
                  that: isRemoteUri(expectedRemoteTag),
                ),
                nonce: expectedNonce,
                key: encryptionKey,
              ),
        ]);
      });

      test('caches remote keys for consecutive use', () async {
        const currentKeyId1 = 111;
        const currentKeyId2 = 222;
        final cryptoResult = DetachedCipherResult(
          cipherText: Uint8List.fromList(List.filled(9, 9)),
          mac: Uint8List.fromList(List.filled(18, 18)),
        );

        const testJson = 42;

        when(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: any(named: 'keyId'),
            storeId: any(named: 'storeId'),
            keyBytes: any(named: 'keyBytes'),
          ),
        ).thenAnswer((i) async => FakeSecureKey());

        when(() => mockAead.keyBytes).thenReturn(0);
        when(() => mockAead.nonceBytes).thenReturn(0);
        when(
          () => mockAead.encryptDetached(
            message: any(named: 'message'),
            additionalData: any(named: 'additionalData'),
            nonce: any(named: 'nonce'),
            key: any(named: 'key'),
          ),
        ).thenReturn(cryptoResult);

        when(() => mockRandombytes.buf(any())).thenReturn(Uint8List(0));

        when(() => mockSodiumKeyManager.currentRemoteKeyId)
            .thenReturn(currentKeyId1);
        final result1 = await sut.encrypt(
          remoteUri: remoteUri,
          dataJson: testJson,
        );
        final result2 = await sut.encrypt(
          remoteUri: remoteUri,
          dataJson: testJson,
        );

        when(() => mockSodiumKeyManager.currentRemoteKeyId)
            .thenReturn(currentKeyId2);
        final result3 = await sut.encrypt(
          remoteUri: remoteUri,
          dataJson: testJson,
        );

        expect(result1.keyId, currentKeyId1);
        expect(result2.keyId, currentKeyId1);
        expect(result3.keyId, currentKeyId2);

        verify(() => mockSodiumKeyManager.currentRemoteKeyId).called(3);
        verify(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: currentKeyId1,
            storeId: storeId,
            keyBytes: 0,
          ),
        ).called(1);
        verify(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: currentKeyId2,
            storeId: storeId,
            keyBytes: 0,
          ),
        ).called(1);
        verifyNever(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: any(named: 'keyId'),
            storeId: any(named: 'storeId'),
            keyBytes: any(named: 'keyBytes'),
          ),
        );
      });
    });

    group('decrypt', () {
      test('correctly decrypts and returns plain data', () async {
        final cipherMessage = CipherMessage(
          cipherText: Uint8List.fromList(
            List.generate(99, (index) => 100 - index),
          ),
          mac: Uint8List.fromList(List.generate(10, (index) => index * index)),
          nonce: Uint8List.fromList(List.generate(15, (index) => index + 42)),
          remoteTag: Uint8List.fromList(List.generate(22, (index) => index)),
          keyId: 132,
        );
        final key = FakeSecureKey();
        const aeadKeyBytes = 10;
        const testJson = {
          'a': true,
          'b': [1, 1.2, '123'],
        };

        when(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: any(named: 'keyId'),
            storeId: any(named: 'storeId'),
            keyBytes: any(named: 'keyBytes'),
          ),
        ).thenAnswer((i) async => key);

        when(() => mockAead.keyBytes).thenReturn(aeadKeyBytes);
        when(
          () => mockAead.decryptDetached(
            cipherText: any(named: 'cipherText'),
            additionalData: any(named: 'additionalData'),
            mac: any(named: 'mac'),
            nonce: any(named: 'nonce'),
            key: any(named: 'key'),
          ),
        ).thenReturn(Uint8List.fromList(utf8.encode(json.encode(testJson))));

        final dynamic result = await sut.decrypt(
          remoteUri: remoteUri,
          data: cipherMessage,
        );

        expect(result, testJson);

        verifyInOrder([
          () => mockAead.keyBytes,
          () => mockSodiumKeyManager.remoteEncryptionKey(
                keyId: cipherMessage.keyId,
                storeId: storeId,
                keyBytes: aeadKeyBytes,
              ),
          () => mockAead.decryptDetached(
                cipherText: cipherMessage.cipherText,
                additionalData: any(
                  named: 'additionalData',
                  that: isRemoteUri(cipherMessage.remoteTag),
                ),
                mac: cipherMessage.mac,
                nonce: cipherMessage.nonce,
                key: key,
              ),
        ]);
      });

      test('caches remote keys for consecutive use', () async {
        final cipherMessage1 = CipherMessage(
          cipherText: Uint8List(0),
          mac: Uint8List(0),
          nonce: Uint8List(0),
          remoteTag: Uint8List(0),
          keyId: 132,
        );
        final cipherMessage2 = cipherMessage1.copyWith();
        final cipherMessage3 = cipherMessage1.copyWith(keyId: 231);

        when(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: any(named: 'keyId'),
            storeId: any(named: 'storeId'),
            keyBytes: any(named: 'keyBytes'),
          ),
        ).thenAnswer((i) async => FakeSecureKey());

        when(() => mockAead.keyBytes).thenReturn(0);
        when(
          () => mockAead.decryptDetached(
            cipherText: any(named: 'cipherText'),
            additionalData: any(named: 'additionalData'),
            mac: any(named: 'mac'),
            nonce: any(named: 'nonce'),
            key: any(named: 'key'),
          ),
        ).thenReturn(Uint8List.fromList(utf8.encode(json.encode(null))));

        await sut.decrypt(
          remoteUri: remoteUri,
          data: cipherMessage1,
        );
        await sut.decrypt(
          remoteUri: remoteUri,
          data: cipherMessage2,
        );
        await sut.decrypt(
          remoteUri: remoteUri,
          data: cipherMessage3,
        );

        verify(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: cipherMessage1.keyId,
            storeId: storeId,
            keyBytes: 0,
          ),
        );
        verify(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: cipherMessage3.keyId,
            storeId: storeId,
            keyBytes: 0,
          ),
        );
        verifyNever(
          () => mockSodiumKeyManager.remoteEncryptionKey(
            keyId: any(named: 'keyId'),
            storeId: any(named: 'storeId'),
            keyBytes: any(named: 'keyBytes'),
          ),
        );
      });
    });
  });
}
