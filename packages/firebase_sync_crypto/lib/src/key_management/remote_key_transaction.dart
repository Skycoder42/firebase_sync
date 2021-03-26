import 'package:cryptography/cryptography.dart';
import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'remote_key_store.dart';

@internal
class RemoteKeyTransaction implements FirebaseTransaction<SecretKey> {
  final RemoteKeyStore remoteKeyStore;

  @override
  final String eTag;

  @override
  final String key;

  @override
  final SecretKey? value;

  const RemoteKeyTransaction({
    required this.remoteKeyStore,
    required this.eTag,
    required this.key,
    required this.value,
  });

  @override
  Future<void> commitDelete() => remoteKeyStore.delete(key, eTag: eTag);

  @override
  Future<SecretKey?> commitUpdate(SecretKey data) async {
    await remoteKeyStore.encryptAndWrite(
      key,
      data,
      eTag: eTag,
    );
    return null;
  }
}
