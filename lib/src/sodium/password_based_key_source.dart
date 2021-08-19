import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sodium/sodium.dart';

import 'key_source.dart';

part 'password_based_key_source.freezed.dart';

@freezed
class MasterKeyComponents with _$MasterKeyComponents {
  const factory MasterKeyComponents({
    required String password,
    int? opsLimit,
    int? memLimit,
  }) = _MasterKeyComponents;
}

@freezed
class MasterKeyRequest with _$MasterKeyRequest {
  const factory MasterKeyRequest._({
    required MasterKeyComponents components,
    required RemoteKeyType keyType,
  }) = _MasterKeyRequest;
}

abstract class PasswordBasedKeySource extends PersistentKeySource {
  static SecureKey computeMasterKey(
    Sodium sodium,
    MasterKeyRequest masterKeyRequest,
  ) =>
      sodium.crypto.pwhash.call(
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

  final Sodium sodium;

  PasswordBasedKeySource(this.sodium);

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
      MasterKeyRequest._(
        components: components,
        keyType: remoteKeyType,
      ),
    );
  }
}

extension _KeyTypeSaltX on KeyType {
  Uint8List toJsonBytes() => json.encode(toJson()).toCharArray().unsignedView();
}
