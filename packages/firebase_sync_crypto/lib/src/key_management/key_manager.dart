import 'package:cryptography/cryptography.dart';

abstract class KeyInfo {
  SecretKey get secretKey;
  String get keyId;
}

abstract class KeyManager {
  Future<KeyInfo> obtainKey() {
    throw UnimplementedError();
  }

  Future<KeyInfo> obtainKeyForId(String keyId) {
    throw UnimplementedError();
  }
}
