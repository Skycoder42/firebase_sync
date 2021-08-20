import 'dart:async';

import 'package:sodium/sodium.dart';
import 'package:tuple/tuple.dart';

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
  static const _localMasterKeyContext = 'fbslocal';
  static const _remoteMasterKeyContext = 'fbs_sync';
  static const _remoteRotationKeyContext = 'fbss_rot';

  static const _daysPerMonth = 30;

  static const defaultLockTimeout = Duration(seconds: 10);

  final Sodium sodium;
  final KeySource keySource;
  final String database;
  final String localId;

  Duration lockTimeout;

  SecureKey? _cachedLocalMasterKey;
  SecureKey? _cachedRemoteMasterKey;
  final _cachedRemoteRotationKeys = <int, SecureKey>{};
  Timer? _lockoutTimer;

  final _remoteKeys = <Tuple2<int, int>, SecureKey>{};

  SodiumKeyManager({
    required this.sodium,
    required this.keySource,
    required this.database,
    required this.localId,
    this.lockTimeout = defaultLockTimeout,
  });

  void dispose() {
    _clearKeys();

    for (final key in _remoteKeys.values) {
      key.dispose();
    }
    _remoteKeys.clear();
  }

  Future<SecureKey> localEncryptionKey({
    required int storeId,
    required int keyBytes,
  }) async =>
      sodium.crypto.kdf.deriveFromKey(
        masterKey: await _obtainLocalMasterKey(),
        context: _localMasterKeyContext,
        subkeyId: storeId,
        subkeyLen: keyBytes,
      );

  int get currentRemoteKeyId => _keyIdForDate(DateTime.now().toUtc());

  Future<SecureKey> remoteEncryptionKey({
    required int keyId,
    required int storeId,
    required int keyBytes,
  }) async {
    final key = Tuple2(keyId, storeId);
    _remoteKeys[key] ??= sodium.crypto.kdf.deriveFromKey(
      masterKey: await _obtainRemoteRotationKey(keyId),
      context: _remoteRotationKeyContext,
      subkeyId: storeId,
      subkeyLen: keyBytes,
    );

    return _remoteKeys[key]!;
  }

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
      context: _remoteMasterKeyContext,
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
