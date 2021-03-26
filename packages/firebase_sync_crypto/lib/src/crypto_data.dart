import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'crypto_data.freezed.dart';
part 'crypto_data.g.dart';

@freezed
class CryptoData with _$CryptoData {
  const CryptoData._();

  // ignore: sort_unnamed_constructors_first
  const factory CryptoData({
    required String nonce,
    required String cipher,
    required String mac,
    required String keyId,
  }) = _CryptoData;

  factory CryptoData.fromSecretBox(SecretBox box, String keyId) => CryptoData(
        nonce: base64.encode(box.nonce),
        cipher: base64.encode(box.cipherText),
        mac: base64.encode(box.mac.bytes),
        keyId: keyId,
      );

  factory CryptoData.fromJson(Map<String, dynamic> json) =>
      _$CryptoDataFromJson(json);

  SecretBox toSecretBox() => SecretBox(
        base64.decode(cipher),
        nonce: base64.decode(nonce),
        mac: Mac(base64.decode(mac)),
      );
}
