import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/box/default_compaction_strategy.dart';
// ignore: implementation_imports
import 'package:hive/src/box/default_key_comparator.dart';
import 'package:meta/meta.dart';
import 'package:sodium/sodium.dart';

import '../core/firebase_sync_base.dart';
import '../core/store/sync_object.dart';
import '../core/sync/conflict_resolver.dart';
import '../core/sync/sync_mode.dart';
import '../sodium/key_source.dart';
import '../sodium/sodium_data_encryptor.dart';
import '../sodium/sodium_key_manager.dart';
import '../sodium/uuid_extension.dart';
import 'crypto/sodium_hive_cipher.dart';
import 'hive_offline_store.dart';
import 'hive_sync_object_store.dart';
import 'hive_sync_store.dart';
import 'lazy_hive_offline_store.dart';
import 'sync_object_adapter.dart';

class FirebaseSyncHive extends FirebaseSyncBase {
  final HiveInterface hive;
  final Sodium sodium;
  final KeySource keySource;

  final String? localId;

  @override
  final FirebaseStore<dynamic> rootStore;

  late final SodiumKeyManager _keyManager = SodiumKeyManager(
    keySource: keySource,
    sodium: sodium,
    database: rootStore.restApi.database,
    localId: localId,
  );

  FirebaseSyncHive({
    required this.hive,
    required this.sodium,
    required this.keySource,
    required this.localId,
    required this.rootStore,
  }) : assert(
          localId != null || rootStore.restApi.idToken == null,
          'If the rootStore uses authentication, a localId is required',
        );

  @override
  Future<HiveSyncStore<T>> openStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required covariant TypeAdapter<T> storageConverter,
    SyncMode syncMode = SyncMode.sync,
    ConflictResolver<T>? conflictResolver,
    int? storeId,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) =>
      createStore(name, (onClosed) async {
        // TODO test typing
        _registerTypeAdapter(storageConverter);

        final box = await hive.openBox<SyncObject<T>>(
          name,
          encryptionCipher: await _createCipher(
            storeId ?? storageConverter.typeId,
          ),
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
        );

        final store = HiveSyncStore(
          rawBox: box,
          uuid: sodium.uuid,
          syncNode: createSyncNode(
            storeName: name,
            localStore: HiveSyncObjectStore(box),
            jsonConverter: jsonConverter,
            dataEncryptor: SodiumDataEncryptor(
              sodium: sodium,
              keyManager: _keyManager,
              storeId: storeId ?? storageConverter.typeId,
            ),
            conflictResolver: conflictResolver,
          ),
          onClose: onClosed,
        );
        await store.setSyncMode(syncMode);
        return store;
      });

  Future<LazyHiveSyncStore<T>> openLazyStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required covariant TypeAdapter<T> storageConverter,
    SyncMode syncMode = SyncMode.sync,
    int? storeId,
    ConflictResolver<T>? conflictResolver,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) =>
      createStore(name, (onClosed) async {
        _registerTypeAdapter(storageConverter);

        final box = await hive.openLazyBox<SyncObject<T>>(
          name,
          encryptionCipher: await _createCipher(
            storeId ?? storageConverter.typeId,
          ),
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
        );

        final store = LazyHiveSyncStore(
          rawBox: box,
          uuid: sodium.uuid,
          syncNode: createSyncNode(
            storeName: name,
            localStore: LazyHiveSyncObjectStore(box),
            jsonConverter: jsonConverter,
            dataEncryptor: SodiumDataEncryptor(
              sodium: sodium,
              keyManager: _keyManager,
              storeId: storeId ?? storageConverter.typeId,
            ),
            conflictResolver: conflictResolver,
          ),
          onClosed: onClosed,
        );
        await store.setSyncMode(syncMode);
        return store;
      });

  @override
  Future<HiveOfflineStore<T>> openOfflineStore<T extends Object>({
    required String name,
    required covariant TypeAdapter<T> storageConverter,
    int? storeId,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) =>
      createStore(name, (onClosed) async {
        hive.registerAdapter(storageConverter);

        final box = await hive.openBox<T>(
          name,
          encryptionCipher: await _createCipher(
            storeId ?? storageConverter.typeId,
          ),
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
        );

        return HiveOfflineStore(
          rawBox: box,
          uuid: sodium.uuid,
          onClosed: onClosed,
        );
      });

  Future<LazyHiveOfflineStore<T>> openLazyOfflineStore<T extends Object>({
    required String name,
    required covariant TypeAdapter<T> storageConverter,
    int? storeId,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) =>
      createStore(name, (onClosed) async {
        hive.registerAdapter(storageConverter);

        final box = await hive.openLazyBox<T>(
          name,
          encryptionCipher: await _createCipher(
            storeId ?? storageConverter.typeId,
          ),
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
        );

        return LazyHiveOfflineStore(
          rawBox: box,
          uuid: sodium.uuid,
          onClosed: onClosed,
        );
      });

  @override
  HiveSyncStore<T> store<T extends Object>(String name) =>
      getStore(name); // TODO test typing

  LazyHiveSyncStore<T> lazyStore<T extends Object>(String name) =>
      getStore(name);

  @override
  HiveOfflineStore<T> offlineStore<T extends Object>(String name) =>
      getStore(name);

  LazyHiveOfflineStore<T> lazyOfflineStore<T extends Object>(String name) =>
      getStore(name);

  @override
  @mustCallSuper
  Future<void> close() async {
    await super.close();
    await hive.close();
    _keyManager.dispose();
  }

  void _registerTypeAdapter<T extends Object>(TypeAdapter<T> hiveAdapter) {
    hive.registerAdapter(SyncObjectAdapter<T>(hiveAdapter));
  }

  Future<HiveCipher> _createCipher(int storeId) async => SodiumHiveCipher(
        sodium: sodium,
        encryptionKey: await _keyManager.localEncryptionKey(
          storeId: storeId,
          keyBytes: SodiumHiveCipher.keyBytes(sodium),
        ),
      );
}
