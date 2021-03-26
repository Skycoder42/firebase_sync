import 'package:cryptography/cryptography.dart';

abstract class KeyFactory {
  // ignore: unused_element
  const KeyFactory._();

  const factory KeyFactory.simple() = _SimpleKeyFactory;

  Future<SecretKey> createKey(List<int> keyData);

  Future<SecretKey> generateRandom(int length);
}

class _SimpleKeyFactory implements KeyFactory {
  const _SimpleKeyFactory();

  @override
  Future<SecretKey> createKey(List<int> keyData) =>
      Future.value(SecretKey(keyData));

  @override
  Future<SecretKey> generateRandom(int length) =>
      Future.value(SecretKeyData.random(length: length));
}
