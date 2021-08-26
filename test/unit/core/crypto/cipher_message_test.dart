import 'dart:typed_data';

import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_data.dart';

void main() {
  group('CipherMessage', () {
    group('uses Uint8ListConverter', () {
      test('with toJson()', () {
        final sut = CipherMessage(
          cipherText: Uint8List.fromList([1]),
          mac: Uint8List(0),
          nonce: Uint8List(0),
          remoteTag: Uint8List(0),
          keyId: 0,
        );

        final json = sut.toJson();
        final dynamic data = json['cipherText'];
        expect(data, 'AQ==');
      });

      test('with fromJson()', () {
        const json = {
          'cipherText': 'AQ==',
          'mac': '',
          'nonce': '',
          'remoteTag': '',
          'keyId': 0,
        };

        final sut = CipherMessage.fromJson(json);

        expect(sut.cipherText, Uint8List.fromList([1]));
      });
    });
  });

  group('CipherMessageX', () {
    testData<Tuple2<CipherMessage?, Uint8List>>(
      'remoteTagOrDefault returns correct value',
      [
        Tuple2(null, SyncObject.noRemoteDataTag),
        Tuple2(
          CipherMessage(
            cipherText: Uint8List(0),
            mac: Uint8List(0),
            nonce: Uint8List(0),
            remoteTag: Uint8List.fromList([1, 2, 3]),
            keyId: 0,
          ),
          Uint8List.fromList([1, 2, 3]),
        ),
      ],
      (fixture) {
        expect(fixture.item1.remoteTagOrDefault, fixture.item2);
      },
    );
  });
}
