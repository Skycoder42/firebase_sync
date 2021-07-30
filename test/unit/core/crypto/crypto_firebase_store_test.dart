import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_database_rest/rest.dart';
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

class MockRestApi extends Mock implements RestApi {}

class MockFirebaseStore extends Mock implements FirebaseStore<dynamic> {}

void main() {
  const name = 'store-name';
  final mockParent = MockFirebaseStore();
  final mockRestApi = MockRestApi();

  final testCipher = Uint8List.fromList(
    List.generate(100, (index) => 100 - index),
  );
  final testMac = Uint8List.fromList(
    List.generate(20, (index) => index),
  );
  final testNonce = Uint8List.fromList(
    List.generate(40, (index) => 2 * index),
  );
  final testRemoteTag = Uint8List.fromList(
    List.generate(25, (index) => 50 + index),
  );
  const testKeyId = 10;
  final cipherData = CipherMessage(
    cipherText: testCipher,
    mac: testMac,
    nonce: testNonce,
    remoteTag: testRemoteTag,
    keyId: testKeyId,
  );
  final jsonData = <String, dynamic>{
    'cipherText': base64.encode(testCipher),
    'mac': base64.encode(testMac),
    'nonce': base64.encode(testNonce),
    'remoteTag': base64.encode(testRemoteTag),
    'keyId': testKeyId,
  };

  late CryptoFirebaseStore sut;

  setUp(() {
    reset(mockParent);
    reset(mockRestApi);

    when(() => mockParent.restApi).thenReturn(mockRestApi);
    when(() => mockParent.subPaths).thenReturn(const []);

    sut = CryptoFirebaseStore(
      name: name,
      parent: mockParent,
    );
  });

  test('constructs correct store', () {
    expect(sut.restApi, mockRestApi);
    expect(sut.subPaths, const [name]);
  });

  test('dataFromJson uses CipherMessage.fromJson to decode data', () {
    final result = sut.dataFromJson(jsonData);
    expect(result, cipherData);
  });

  test('dataToJson uses CipherMessage.toJson to encode data', () {
    final dynamic result = sut.dataToJson(cipherData);
    expect(result, jsonData);
  });

  test('patchData throw UnsupportedError', () {
    expect(
      () => sut.patchData(cipherData, const <String, dynamic>{}),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
