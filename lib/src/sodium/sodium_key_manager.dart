import 'dart:async';

import 'package:sodium/sodium.dart';

import 'key_source.dart';

class KeyManagerLockedError extends StateError {
  KeyManagerLockedError()
      : super('KeyManager is locked! Call SodiumKeyManager.unlock first');
}

class InvalidRemoteEncryptionKeyId implements Exception {
  final int keyId;

  InvalidRemoteEncryptionKeyId(this.keyId);

  @override
  String toString() => 'Invalid remote key encrption key id: $keyId';
}

class SodiumKeyManager {
  static const _rootContext = 'fbs_root';
  static const _localEncryptionKeyContext = 'fbslocal';
  static const _remoteEncryptionKeyContext = 'fbs_sync';

  static const _localEncryptionKeyId = 0;
  static const _remoteEncryptionKeyOffset = 1;

  static const _daysPerMonth = 30;

  static const defaultLockTimeout = Duration(seconds: 10);

  final Sodium sodium;
  final KeySource keySource;

  Duration lockTimeout;

  SecureKey? _localEncryptionKey;
  final _remoteEncryptionKeys = <int, SecureKey>{};
  int? _currentKeyId;

  SodiumKeyManager({
    required this.sodium,
    required this.keySource,
    this.lockTimeout = defaultLockTimeout,
  });

  void dispose() {
    _localEncryptionKey?.dispose();
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
      subkeyId: keySource.keyIdForStoreName(storeName),
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
      subkeyId: keySource.keyIdForStoreName(storeName),
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
      subkeyId: keySource.keyIdForStoreName(storeName),
      subkeyLen: keyBytes,
    );
  }

  Future<SecureKey> _generateMasterKey() async {
    throw UnimplementedError();
  }

  int _keyIdForDate(DateTime dateTime) {
    final durationSinceEpoche = Duration(
      milliseconds: dateTime.millisecondsSinceEpoch,
    );
    final monthsSinceEpoche = durationSinceEpoche.inDays ~/ _daysPerMonth;
    return _remoteEncryptionKeyOffset + monthsSinceEpoche;
  }
}
