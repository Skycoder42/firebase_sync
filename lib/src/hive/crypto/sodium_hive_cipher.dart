import 'dart:typed_data';

import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/crypto/crc32.dart' as hive;
import 'package:sodium/sodium.dart';

class SodiumHiveCipher implements HiveCipher {
  final Sodium sodium;
  final SecureKey encryptionKey;

  static int keyBytes(Sodium sodium) => sodium.crypto.secretBox.keyBytes;

  SodiumHiveCipher({
    required this.sodium,
    required this.encryptionKey,
  });

  @override
  int calculateKeyCrc() => hive.Crc32.compute(
        encryptionKey.runUnlockedSync(
          (encryptionKeyData) => sodium.crypto.genericHash(
            message: encryptionKeyData,
            outLen: sodium.crypto.genericHash.bytesMax,
          ),
        ),
      );

  @override
  int maxEncryptedSize(Uint8List inp) =>
      inp.length +
      sodium.crypto.secretBox.nonceBytes +
      sodium.crypto.secretBox.macBytes;

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
    out.setAll(outOff, nonce);

    final cipher = sodium.crypto.secretBox.easy(
      message: Uint8List.sublistView(inp, inpOff, inpOff + inpLength),
      nonce: nonce,
      key: encryptionKey,
    );
    out.setAll(outOff + nonce.length, cipher);

    return nonce.length + cipher.length;
  }

  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final nonce = Uint8List.sublistView(
      inp,
      inpOff,
      sodium.crypto.secretBox.nonceBytes,
    );
    final cipher = Uint8List.sublistView(
      inp,
      inpOff + nonce.length,
      inpOff + inpLength,
    );

    final plain = sodium.crypto.secretBox.openEasy(
      cipherText: cipher,
      nonce: nonce,
      key: encryptionKey,
    );
    out.setAll(outOff, plain);
    return plain.length;
  }
}
