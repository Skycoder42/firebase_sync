import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../util/secret_box_x.dart';
import 'key_factory.dart';
import 'remote_key_transaction.dart';

class RemoteKeyStore extends FirebaseStore<SecretBox> {
  static const remoteKeyStorePath = '.meta/keys';

  final KeyFactory keyFactory;
  final StreamingCipher streamingCipher;
  final SecretKey masterKey;

  RemoteKeyStore({
    required FirebaseStore<dynamic> parent,
    required this.keyFactory,
    required this.streamingCipher,
    required this.masterKey,
  }) : super(
          parent: parent,
          path: remoteKeyStorePath,
        );

  RemoteKeyStore.withXchacha20Poly1305({
    required FirebaseStore<dynamic> parent,
    required KeyFactory keyFactory,
    required SecretKey masterKey,
  }) : this(
          parent: parent,
          keyFactory: keyFactory,
          streamingCipher: Xchacha20.poly1305Aead(),
          masterKey: masterKey,
        );

  RemoteKeyStore.withAesGcm({
    required FirebaseStore<dynamic> parent,
    required KeyFactory keyFactory,
    required SecretKey masterKey,
  }) : this(
          parent: parent,
          keyFactory: keyFactory,
          streamingCipher: AesGcm.with256bits(),
          masterKey: masterKey,
        );

  Future<SecretKey?> readAndDecrypt(
    String key, {
    ETagReceiver? eTagReceiver,
  }) async {
    final secretBox = await super.read(key, eTagReceiver: eTagReceiver);
    if (secretBox != null) {
      return keyFactory.createKey(
        await streamingCipher.decrypt(
          secretBox,
          secretKey: masterKey,
          aad: utf8.encode(key),
        ),
      );
    } else {
      return null;
    }
  }

  Future<void> encryptAndWrite(
    String key,
    SecretKey data, {
    bool silent = false,
    String? eTag,
    ETagReceiver? eTagReceiver,
  }) async {
    final secretBox = await streamingCipher.encrypt(
      await data.extractBytes(),
      secretKey: masterKey,
      aad: utf8.encode(key),
    );
    await super.write(
      key,
      secretBox,
      silent: silent,
      eTag: eTag,
      eTagReceiver: eTagReceiver,
    );
  }

  Future<FirebaseTransaction<SecretKey>> keyTransaction(String key) async {
    final eTagReceiver = ETagReceiver();
    final value = await readAndDecrypt(key, eTagReceiver: eTagReceiver);
    return RemoteKeyTransaction(
      remoteKeyStore: this,
      eTag: eTagReceiver.eTag!,
      key: key,
      value: value,
    );
  }

  @override
  SecretBox dataFromJson(dynamic json) =>
      SecretBoxX.fromJson(json as Map<String, dynamic>);

  @override
  dynamic dataToJson(SecretBox data) => data.toJson();

  @override
  SecretBox patchData(SecretBox data, Map<String, dynamic> updatedFields) =>
      data.patch(updatedFields);
}
