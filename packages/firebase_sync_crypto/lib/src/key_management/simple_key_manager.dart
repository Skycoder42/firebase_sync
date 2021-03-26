import 'package:cryptography/cryptography.dart';
import 'key_manager.dart';

class _SimpleKeyInfo implements KeyInfo {
  @override
  final String keyId;

  @override
  final SecretKey secretKey;

  const _SimpleKeyInfo(this.keyId, this.secretKey);
}

class NoCurrentKeyException implements Exception {
  @override
  String toString() => 'The SimpleKeyManager has not been initialized yet and '
      'there is no current key to use for encryption. '
      'Call SimpleKeyManager.addKey to add a key';
}

class SimpleKeyManager implements KeyManager {
  final Map<String, SecretKey> _keys = {};
  String? _currentKey;

  SimpleKeyManager();

  void addKey(String keyId, SecretKey key, {bool? makeCurrent}) {
    _keys[keyId] = key;
    if (makeCurrent ?? _currentKey == null) {
      _currentKey = keyId;
    }
  }

  @override
  Future<KeyInfo> obtainKey() {
    if (_currentKey != null) {
      final currentKey = _keys[_currentKey];
      if (currentKey != null) {
        return Future.value(_SimpleKeyInfo(_currentKey!, currentKey));
      }
    }

    throw NoCurrentKeyException();
  }

  @override
  Future<KeyInfo> obtainKeyForId(String keyId) {
    final key = _keys[keyId];
    return Future.value(key != null ? _SimpleKeyInfo(keyId, key) : null);
  }
}
