import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_key.freezed.dart';
part 'remote_key.g.dart';

@freezed
class RemoteKey with _$RemoteKey {
  const factory RemoteKey({
    required String nonce,
    required String keySalt,
    required String signature,
  }) = _RemoteKey;

  factory RemoteKey.fromJson(Map<String, dynamic> json) =>
      _$RemoteKeyFromJson(json);
}
