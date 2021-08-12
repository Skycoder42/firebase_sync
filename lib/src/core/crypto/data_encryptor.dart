import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'cipher_message.dart';

@internal
abstract class DataEncryptor {
  Uint8List generateRandom(int length);

  Future<CipherMessage> encrypt({
    required String storeName,
    required Uri remoteUri,
    required dynamic dataJson,
  });

  Future<dynamic> decrypt({
    required String storeName,
    required Uri remoteUri,
    required CipherMessage data,
  });
}
