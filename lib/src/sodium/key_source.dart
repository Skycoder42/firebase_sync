import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';
import 'package:sodium/sodium.dart';

part 'key_source.freezed.dart';
part 'key_source.g.dart';

@Freezed(unionKey: KeyType.typeKey)
class KeyType with _$KeyType {
  static const typeKey = 'keyType';
  static const bytesKey = 'bytes';

  const factory KeyType.local({
    required int bytes,
  }) = LocalKeyType;
  const factory KeyType.remote({
    required int bytes,
    required String database,
    required String? localId,
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
    final restoredKey = await restoreKey(keyType);
    if (restoredKey != null) {
      return restoredKey;
    } else {
      final generatedKey = await generateKey(keyType);
      try {
        await persistKey(keyType, generatedKey);
        return generatedKey;
      } catch (e) {
        generatedKey.dispose();
        rethrow;
      }
    }
  }

  @protected
  Future<SecureKey?> restoreKey(KeyType keyType);

  @protected
  Future<SecureKey> generateKey(KeyType keyType);

  @protected
  Future<void> persistKey(KeyType keyType, SecureKey key);
}
