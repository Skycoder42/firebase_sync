import 'package:sodium/sodium.dart';

abstract class KeyManager {
  Future<String> requestPassword();

  Future<SecureKey?> requestKeyfile() => Future.value(null);

  Future<void> persistMasterKey(SecureKey key) => Future.value();

  Future<SecureKey?> restoreMasterKey() => Future.value(null);
}
