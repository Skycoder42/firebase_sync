import 'package:meta/meta.dart';

import 'cipher_message.dart';
import 'crypto_firebase_store.dart';

@internal
abstract class CryptoService {
  String keyHash({
    required String storeName,
    required String key,
  });

  Future<MapEntry<String, CipherMessage>> encrypt({
    required String storeName,
    required CryptoFirebaseStore store,
    required String key,
    required dynamic dataJson,
    String? hashedKey,
  });

  Future<MapEntry<String, dynamic>> decrypt({
    required String storeName,
    required CryptoFirebaseStore store,
    required String hashedKey,
    required CipherMessage data,
  });
}
