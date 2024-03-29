import 'package:meta/meta.dart';

import 'cipher_message.dart';

@internal
abstract class DataEncryptor {
  Future<CipherMessage> encrypt({
    required Uri remoteUri,
    required dynamic dataJson,
  });

  Future<dynamic> decrypt({
    required Uri remoteUri,
    required CipherMessage data,
  });

  void dispose();
}
