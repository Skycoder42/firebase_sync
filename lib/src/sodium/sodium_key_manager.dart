import 'dart:async';

import 'package:clock/clock.dart';
import 'package:sodium/sodium.dart';

import 'key_source.dart';

/// logic
///
/// ```.txt
/// localMasterKey (cache)
///   \-localKey<n:storeName>
/// remoteMasterKey (cache)
///   \-remoteStoreKey<m:date> (cache)
///       \-remoteKey<m,n:storeName> (cache+)
/// ```
class SodiumKeyManager {
  static const _localKeyContext = 'fbslocal';
  static const _remoteKeyContext = 'fbs_sync';
  static const _remoteRotationKeyContext = 'fbss_rot';

  static const _daysPerMonth = 30;

  static const defaultLockTimeout = Duration(seconds: 10);

  final Sodium sodium;
  final KeySource keySource;
  final Clock clock;
  final String database;
  final String? localId;

  Duration lockTimeout;
  Timer? _lockoutTimer;

  SecureKey? _cachedLocalMasterKey;
  SecureKey? _cachedRemoteMasterKey;
  final _cachedRemoteRotationKeys = <int, SecureKey>{};

  SodiumKeyManager({
    required this.sodium,
    required this.keySource,
    required this.database,
    required this.localId,
    this.lockTimeout = defaultLockTimeout,
    this.clock = const Clock(),
  });

  void dispose() => _clearKeys();

  Future<SecureKey> localEncryptionKey({
    required int storeId,
    required int keyBytes,
  }) async =>
      sodium.crypto.kdf.deriveFromKey(
        masterKey: await _obtainLocalMasterKey(),
        context: _localKeyContext,
        subkeyId: storeId,
        subkeyLen: keyBytes,
      );

  int get currentRemoteKeyId => _keyIdForDate(clock.now());

  Future<SecureKey> remoteEncryptionKey({
    required int keyId,
    required int storeId,
    required int keyBytes,
  }) async =>
      sodium.crypto.kdf.deriveFromKey(
        masterKey: await _obtainRemoteRotationKey(keyId),
        context: _remoteKeyContext,
        subkeyId: storeId,
        subkeyLen: keyBytes,
      );

  Future<SecureKey> _obtainLocalMasterKey() async {
    _cachedLocalMasterKey ??= await keySource.obtainMasterKey(
      KeyType.local(bytes: sodium.crypto.kdf.keyBytes),
    );
    _resetTimer();

    return _cachedLocalMasterKey!;
  }

  Future<SecureKey> _obtainRemoteMasterKey() async {
    _cachedRemoteMasterKey ??= await keySource.obtainMasterKey(
      KeyType.remote(
        bytes: sodium.crypto.kdf.keyBytes,
        database: database,
        localId: localId,
      ),
    );
    _resetTimer();

    return _cachedRemoteMasterKey!;
  }

  Future<SecureKey> _obtainRemoteRotationKey(int keyId) async {
    _cachedRemoteRotationKeys[keyId] ??= sodium.crypto.kdf.deriveFromKey(
      masterKey: await _obtainRemoteMasterKey(),
      context: _remoteRotationKeyContext,
      subkeyId: keyId,
      subkeyLen: sodium.crypto.kdf.keyBytes,
    );
    _resetTimer();

    return _cachedRemoteRotationKeys[keyId]!;
  }

  void _resetTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer(lockTimeout, _clearKeys);
  }

  int _keyIdForDate(DateTime dateTime) {
    final durationSinceEpoche = Duration(
      milliseconds: dateTime.millisecondsSinceEpoch,
    );
    final monthsSinceEpoche = durationSinceEpoche.inDays ~/ _daysPerMonth;
    return monthsSinceEpoche;
  }

  void _clearKeys() {
    _cachedLocalMasterKey?.dispose();
    _cachedRemoteMasterKey?.dispose();
    for (final key in _cachedRemoteRotationKeys.values) {
      key.dispose();
    }

    _cachedLocalMasterKey = null;
    _cachedRemoteMasterKey = null;
    _cachedRemoteRotationKeys.clear();

    _lockoutTimer?.cancel();
    _lockoutTimer = null;
  }
}
