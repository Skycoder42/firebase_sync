import 'dart:async';
import 'dart:isolate';

import 'package:sodium/sodium.dart';

import 'key_controller.dart';

// TODO make an error?
class KeyManagerLockedError extends StateError {
  KeyManagerLockedError()
      : super('KeyManager is locked! Call SodiumKeyManager.unlock first');
}

class InvalidRemoteEncryptionKeyId implements Exception {
  final int keyId;

  InvalidRemoteEncryptionKeyId(this.keyId);

  @override
  String toString() => 'Invalid remote key encryption key id: $keyId';
}

class SodiumKeyManager {
  static const _rootContext = 'fbs_root';
  static const _localEncryptionKeyContext = 'fbslocal';
  static const _remoteEncryptionKeyContext = 'fbs_sync';

  static const _localEncryptionKeyId = 0;
  static const _remoteEncryptionKeyOffset = 1;

  static const _daysPerMonth = 30;

  final Sodium sodium;
  final KeyController keyController;

  SecureKey? _localEncryptionKey;
  SecureKey? _keyHashingKey;
  final _remoteEncryptionKeys = <int, SecureKey>{};
  int? _currentKeyId;

  SodiumKeyManager({
    required this.sodium,
    required this.keyController,
  });

  void dispose() {
    _localEncryptionKey?.dispose();
    _keyHashingKey?.dispose();
    for (final key in _remoteEncryptionKeys.values) {
      key.dispose();
    }
  }

  Future<void> unlock({
    DateTime? now,
  }) async {
    final masterKey = await _generateMasterKey();
    try {
      _localEncryptionKey = sodium.crypto.kdf.deriveFromKey(
        masterKey: masterKey,
        context: _rootContext,
        subkeyId: _localEncryptionKeyId,
        subkeyLen: sodium.crypto.kdf.keyBytes,
      );

      final currentKeyId = _keyIdForDate(now ?? DateTime.now().toUtc());
      _remoteEncryptionKeys[currentKeyId] = sodium.crypto.kdf.deriveFromKey(
        masterKey: masterKey,
        context: _rootContext,
        subkeyId: currentKeyId,
        subkeyLen: sodium.crypto.kdf.keyBytes,
      );
      _currentKeyId = currentKeyId;
    } finally {
      masterKey.dispose();
    }
  }

  SecureKey localEncryptionKey({
    required String storeName,
    required int keyBytes,
  }) {
    if (_localEncryptionKey == null) {
      throw KeyManagerLockedError();
    }

    return sodium.crypto.kdf.deriveFromKey(
      masterKey: _localEncryptionKey!,
      context: _localEncryptionKeyContext,
      subkeyId: keyController.idForStoreName(storeName),
      subkeyLen: keyBytes,
    );
  }

  MapEntry<int, SecureKey> remoteEncryptionKey({
    required String storeName,
    required int keyBytes,
  }) {
    if (_currentKeyId == null ||
        !_remoteEncryptionKeys.containsKey(_currentKeyId)) {
      throw KeyManagerLockedError();
    }

    final key = sodium.crypto.kdf.deriveFromKey(
      masterKey: _remoteEncryptionKeys[_currentKeyId!]!,
      context: _remoteEncryptionKeyContext,
      subkeyId: keyController.idForStoreName(storeName),
      subkeyLen: keyBytes,
    );

    return MapEntry(_currentKeyId!, key);
  }

  Future<SecureKey> remoteEncryptionKeyForId({
    required String storeName,
    required int keyId,
    required int keyBytes,
  }) async {
    if (keyId < _remoteEncryptionKeyOffset) {
      throw InvalidRemoteEncryptionKeyId(keyId);
    }

    if (!_remoteEncryptionKeys.containsKey(keyId)) {
      final masterKey = await _generateMasterKey();
      try {
        _remoteEncryptionKeys[keyId] = sodium.crypto.kdf.deriveFromKey(
          masterKey: masterKey,
          context: _rootContext,
          subkeyId: keyId,
          subkeyLen: sodium.crypto.kdf.keyBytes,
        );
      } finally {
        masterKey.dispose();
      }
    }

    return sodium.crypto.kdf.deriveFromKey(
      masterKey: _remoteEncryptionKeys[keyId]!,
      context: _remoteEncryptionKeyContext,
      subkeyId: keyController.idForStoreName(storeName),
      subkeyLen: keyBytes,
    );
  }

  Future<SecureKey> _generateMasterKey() async {
    final components = await keyController.obtainMasterKey();
    final masterKey = sodium.secureAlloc(sodium.crypto.kdf.keyBytes);
    final resultPort = ReceivePort();
    final errorPort = ReceivePort();
    Isolate? isolate;
    try {
      final completer = Completer<SecureKey>();
      isolate = await Isolate.spawn(
        _computeMasterKey,
        _MasterKeyComputeComponents(sodium, components, masterKey),
        errorsAreFatal: true,
        onExit: resultPort.sendPort,
        onError: errorPort.sendPort,
      );
      errorPort.listen((dynamic message) {
        if (!completer.isCompleted) {
          completer.completeError(message is Object ? message : Exception());
        }
      });
      resultPort.listen((dynamic message) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
      return masterKey;
    } catch (e) {
      masterKey.dispose();
      rethrow;
    } finally {
      resultPort.close();
      errorPort.close();
      isolate?.kill();
    }
  }

  int _keyIdForDate(DateTime dateTime) {
    final durationSinceEpoche = Duration(
      milliseconds: dateTime.millisecondsSinceEpoch,
    );
    final monthsSinceEpoche = durationSinceEpoche.inDays ~/ _daysPerMonth;
    return _remoteEncryptionKeyOffset + monthsSinceEpoche;
  }

  static void _computeMasterKey(_MasterKeyComputeComponents components) {
    final masterKey = components.sodium.crypto.pwhash.call(
      outLen: components.outKey.length,
      password: components.components.password
          .toCharArray(), // TODO join with keyfile
      // TODO better way?
      salt: components.sodium.crypto.genericHash(
        outLen: components.sodium.crypto.pwhash.saltBytes,
        message:
            components.components.firebaseLocalId.toCharArray().unsignedView(),
      ),
      opsLimit: components.components.opsLimit ??
          components.sodium.crypto.pwhash.opsLimitSensitive,
      memLimit: components.components.memLimit ??
          components.sodium.crypto.pwhash.memLimitSensitive,
    );
    try {
      components.outKey.runUnlockedSync(
        (outKeyData) => masterKey.runUnlockedSync(
          (masterKeyData) => outKeyData.setRange(
            0,
            outKeyData.length,
            masterKeyData,
          ),
        ),
        writable: true,
      );
    } finally {
      masterKey.dispose();
    }
  }
}

class _MasterKeyComputeComponents {
  final Sodium sodium;
  final MasterKeyComponents components;
  final SecureKey outKey;

  const _MasterKeyComputeComponents(this.sodium, this.components, this.outKey);
}
