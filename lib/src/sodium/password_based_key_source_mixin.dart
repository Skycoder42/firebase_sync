import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sodium/sodium.dart';

import 'key_source.dart';

part 'password_based_key_source_mixin.freezed.dart';
part 'password_based_key_source_mixin.g.dart';

@freezed
class MasterKeyComponents with _$MasterKeyComponents {
  const factory MasterKeyComponents({
    required String password,
    int? opsLimit,
    int? memLimit,
  }) = _MasterKeyComponents;

  factory MasterKeyComponents.fromJson(Map<String, dynamic> json) =>
      _$MasterKeyComponentsFromJson(json);
}

@freezed
class MasterKeyRequest with _$MasterKeyRequest {
  @visibleForTesting
  const factory MasterKeyRequest.internal({
    required MasterKeyComponents components,
    required RemoteKeyType keyType,
  }) = _MasterKeyRequest;

  factory MasterKeyRequest.fromJson(Map<String, dynamic> json) =>
      _$MasterKeyRequestFromJson(json);
}

mixin PasswordBasedKeySourceMixin on PersistentKeySource {
  static SecureKey computeMasterKey(
    Sodium sodium,
    MasterKeyRequest masterKeyRequest,
  ) =>
      sodium.crypto.pwhash(
        outLen: masterKeyRequest.keyType.bytes,
        password: masterKeyRequest.components.password.toCharArray(),
        salt: sodium.crypto.genericHash(
          outLen: sodium.crypto.pwhash.saltBytes,
          message: masterKeyRequest.keyType.toJsonBytes(),
        ),
        opsLimit: masterKeyRequest.components.opsLimit ??
            sodium.crypto.pwhash.opsLimitSensitive,
        memLimit: masterKeyRequest.components.memLimit ??
            sodium.crypto.pwhash.memLimitSensitive,
      );

  @protected
  Sodium get sodium;

  @override
  @nonVirtual
  @protected
  Future<SecureKey> generateKey(KeyType keyType) => keyType.map(
        local: _generateLocal,
        remote: _generateRemote,
      );

  @protected
  Future<MasterKeyComponents> obtainMasterKeyComponents();

  @protected
  Future<SecureKey> derieveKey(MasterKeyRequest masterKeyRequest) =>
      Future(() => computeMasterKey(sodium, masterKeyRequest));

  Future<SecureKey> _generateLocal(LocalKeyType localKeyType) =>
      Future.value(sodium.secureRandom(localKeyType.bytes));

  Future<SecureKey> _generateRemote(RemoteKeyType remoteKeyType) async {
    final components = await obtainMasterKeyComponents();
    return derieveKey(
      MasterKeyRequest.internal(
        components: components,
        keyType: remoteKeyType,
      ),
    );
  }
}

extension _KeyTypeSaltX on RemoteKeyType {
  static const remoteKeys = [KeyType.typeKey, KeyType.bytesKey];

  Uint8List toJsonBytes() => json
      .encode(
        toJson()
          ..removeWhere(
            (key, dynamic _value) => remoteKeys.contains(key),
          ),
      )
      .toCharArray()
      .unsignedView();
}
