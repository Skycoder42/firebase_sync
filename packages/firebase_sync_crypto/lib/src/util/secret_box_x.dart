import 'dart:convert';

import 'package:cryptography/cryptography.dart';

extension SecretBoxX on SecretBox {
  static SecretBox fromJson(Map<String, dynamic> json) => SecretBox(
        base64.decode(json['cipherText'] as String),
        nonce: base64.decode(json['nonce'] as String),
        mac: Mac(base64.decode(json['mac'] as String)),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cipherText': base64.encode(cipherText),
        'nonce': base64.encode(nonce),
        'mac': base64.encode(mac.bytes),
      };

  SecretBox patch(Map<String, dynamic> patchData) => SecretBox(
        patchData.containsKey('cipherText')
            ? base64.decode(patchData['cipherText'] as String)
            : cipherText,
        nonce: patchData.containsKey('nonce')
            ? base64.decode(patchData['nonce'] as String)
            : nonce,
        mac: patchData.containsKey('mac')
            ? Mac(base64.decode(patchData['mac'] as String))
            : mac,
      );
}
