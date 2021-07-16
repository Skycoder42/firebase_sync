/// <master key> = PBKDF(<password> + <firebase account id> [+ <kefile>])
///   -> <local encryption key> = KDF(<master key>, 'fbs_root', 0)
///     -> <local store encryption key>:n = KDF(<local encryption key>, 'fbslocal', n); n = ID(<store>)
///   -> <key hashing key> = KDF(<master key>, 'fbs_root', 1)
///     -> <store key hashing key>:n = KDF(<key hashing key>, 'fbs_keys', n); n = ID(<store>)
///   -> <remote encryption key>:n = KDF(<master key>, 'fbs_root', n + 2); n := 0..(2^64)-3
///     -> <remote store encryption key>:m = KDF(<remote encryption key>:n, 'fbs_sync', m); m = ID(<store>)
abstract class KeyManager<TKey extends Object> {
  Future<TKey> localEncryptionKey(String storeName, int keyBytes);

  Future<TKey> keyHashingKey(String storeName, int keyBytes);

  Future<TKey> remoteEncryptionKey(String storeName, int keyBytes);
}
