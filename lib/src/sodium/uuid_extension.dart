import 'package:sodium/sodium.dart';
import 'package:uuid/uuid.dart';

extension SodiumUuidX on Sodium {
  static final _expandos = Expando<Uuid>();

  Uuid get uuid => _expandos[this] ??= Uuid(options: <String, dynamic>{
        'grng': () => randombytes.buf(16),
      });
}
