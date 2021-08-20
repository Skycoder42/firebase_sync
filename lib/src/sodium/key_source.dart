import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';
import 'package:sodium/sodium.dart';

part 'key_source.freezed.dart';
part 'key_source.g.dart';

@freezed
class KeyType with _$KeyType {
  const factory KeyType.local({
    required int bytes,
  }) = LocalKeyType;
  const factory KeyType.remote({
    required int bytes,
    required String database,
    required String localId,
  }) = RemoteKeyType;

  factory KeyType.fromJson(Map<String, dynamic> json) =>
      _$KeyTypeFromJson(json);
}

abstract class KeySource {
  const KeySource._();

  Future<SecureKey> obtainMasterKey(KeyType keyType);
}

abstract class PersistentKeySource implements KeySource {
  @override
  @nonVirtual
  Future<SecureKey> obtainMasterKey(KeyType keyType) async {
    if (await hasPersistentKey(keyType)) {
      return restoreKey(keyType);
    } else {
      final key = await generateKey(keyType);
      try {
        await persistKey(keyType, key);
        return key;
      } catch (e) {
        key.dispose();
        rethrow;
      }
    }
  }

  @protected
  Future<bool> hasPersistentKey(KeyType keyType);

  @protected
  Future<void> persistKey(KeyType keyType, SecureKey key);

  @protected
  Future<SecureKey> restoreKey(KeyType keyType);

  @protected
  Future<SecureKey> generateKey(KeyType keyType);
}
