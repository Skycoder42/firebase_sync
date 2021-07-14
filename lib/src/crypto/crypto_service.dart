import 'package:meta/meta.dart';

@internal
abstract class CryptoService<TPlain, TCipher> {
  TCipher encrypt({
    required String store,
    required String key,
    required TPlain data,
  });

  TPlain decrypt({
    required String store,
    required String key,
    required TCipher data,
  });
}
