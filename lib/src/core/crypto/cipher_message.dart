import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../util/uint8list_converter.dart';

part 'cipher_message.freezed.dart';
part 'cipher_message.g.dart';

@freezed
class CipherMessage with _$CipherMessage {
  static const remoteTagSize = 32;

  @Uint8ListConverter()
  const factory CipherMessage({
    required Uint8List cipherText,
    required Uint8List mac,
    required Uint8List nonce,
    required Uint8List remoteTag,
    required int keyId,
  }) = _CipherMessage;

  factory CipherMessage.fromJson(Map<String, dynamic> json) =>
      _$CipherMessageFromJson(json);
}
