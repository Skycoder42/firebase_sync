import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../../../src/core/crypto/cipher_message.dart';

@internal
abstract class CryptoService {
  String keyHash(String key);

  MapEntry<String, CipherMessage> encrypt({
    required FirebaseStore<dynamic> store,
    required String key,
    required dynamic dataJson,
    String? hashedKey,
  });

  MapEntry<String, dynamic> decrypt({
    required FirebaseStore<dynamic> store,
    required String hashedKey,
    required CipherMessage data,
  });
}
