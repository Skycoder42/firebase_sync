import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_controller.freezed.dart';

@freezed
class MasterKeyComponents with _$MasterKeyComponents {
  const factory MasterKeyComponents({
    required String firebaseLocalId,
    required String password,
    String? keyfile,
    int? opsLimit,
    int? memLimit,
  }) = _MasterKeyComponents;
}

abstract class KeyController {
  const KeyController._();

  Future<MasterKeyComponents> obtainMasterKey();

  int idForStoreName(String name);
}
