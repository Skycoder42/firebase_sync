import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import './key_manager.dart';
import 'key_factory.dart';
import 'remote_key_store.dart';

class _SimpleKeyInfo implements KeyInfo {
  @override
  final SecretKey secretKey;
  @override
  final String keyId;

  const _SimpleKeyInfo(this.secretKey, this.keyId);
}

abstract class RotatingPasswordKeyManager implements KeyManager {
  static const remoteKeyStorePath = '.meta/keys';
  static const threeMonthsAsMs = 3 * 30 * 24 * 60 * 60 * 1000;

  final KdfAlgorithm kdfAlgorithm;
  final FirebaseDatabase database;
  final KeyFactory keyFactory;
  final RemoteKeyStore remoteKeyStore;

  final Map<String, SecretKey> _keyCache = {};

  RotatingPasswordKeyManager({
    required this.database,
    required this.keyFactory,
    required this.kdfAlgorithm,
    required this.remoteKeyStore,
  });

  RotatingPasswordKeyManager.withArgon2id({
    required FirebaseDatabase database,
    required KeyFactory keyFactory,
    required RemoteKeyStore remoteKeyStore,
    required int parallelism,
    required int memorySize,
    required int iterations,
  }) : this(
          database: database,
          keyFactory: keyFactory,
          remoteKeyStore: remoteKeyStore,
          kdfAlgorithm: Argon2id(
            parallelism: parallelism,
            memorySize: memorySize,
            iterations: iterations,
            hashLength: 64, // 256 bit
          ),
        );

  @protected
  Future<String> requestMasterPassword();

  @override
  Future<KeyInfo> obtainKey() => obtainKeyForId(currentKeyId);

  @override
  Future<KeyInfo> obtainKeyForId(String keyId) async {
    if (_keyCache.containsKey(keyId)) {
      return _SimpleKeyInfo(_keyCache[keyId]!, keyId);
    }

    final transaction = await remoteKeyStore.keyTransaction(keyId);
    late final SecretKey secretKey;
    if (transaction.value == null) {
      SecretKey? newKey;
      while (newKey == null) {
        try {
          // TODO use cipher?
          newKey = await keyFactory
              .generateRandom(remoteKeyStore.streamingCipher.secretKeyLength);
          await transaction.commitUpdate(newKey);
        } on TransactionFailedException {
          newKey = null;
        }
      }
      secretKey = newKey;
    } else {
      secretKey = transaction.value!;
    }

    _keyCache[keyId] = secretKey;
    return _SimpleKeyInfo(secretKey, keyId);
  }

  String get currentKeyId =>
      '_${DateTime.now().toUtc().millisecondsSinceEpoch ~/ threeMonthsAsMs}';

  Future<SecretKey> _loadMasterKey() async {
    final userInfo = await database.account!.getDetails();
    final nonce = database.account!.localId + (userInfo?.createdAt ?? '');
    return kdfAlgorithm.deriveKey(
      secretKey: await keyFactory.createKey(
        utf8.encode(await requestMasterPassword()),
      ),
      nonce: utf8.encode(nonce),
    );
  }
}
