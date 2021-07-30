import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';

import 'cipher_message.dart';
import 'crypto_firebase_store.dart';

part 'data_encryptor.freezed.dart';

@freezed
class DecryptResult with _$DecryptResult {
  const DecryptResult._();

  const factory DecryptResult({
    required dynamic jsonData,
  }) = _Result;

  const factory DecryptResult.withPlainKey({
    required dynamic jsonData,
    required String plainKey,
  }) = _WithKey;

  String get plainKey => throw StateError(
        'Must set extractKey on DataEncryptor.decrypt to true '
        'to get plain keys from encrypted data',
      );
}

@internal
abstract class DataEncryptor {
  Future<CipherMessage> encrypt({
    required String storeName,
    required CryptoFirebaseStore store,
    required String key,
    required dynamic dataJson,
    String? plainKey,
  });

  Future<DecryptResult> decrypt({
    required String storeName,
    required CryptoFirebaseStore store,
    required String key,
    required CipherMessage data,
    bool extractKey = false,
  });
}
