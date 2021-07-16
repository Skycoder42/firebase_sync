import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../util/uint8list_converter.dart';

part 'cipher_message.freezed.dart';
part 'cipher_message.g.dart';

@freezed
class CipherMessage with _$CipherMessage {
  @Uint8ListConverter()
  const factory CipherMessage({
    required Uint8List cipherText,
    required Uint8List mac,
    required Uint8List nonce,
  }) = _CipherMessage;

  factory CipherMessage.fromJson(Map<String, dynamic> json) =>
      _$CipherMessageFromJson(json);
}
