import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/box/default_compaction_strategy.dart';
// ignore: implementation_imports
import 'package:hive/src/box/default_key_comparator.dart';
import 'package:sodium/sodium.dart';

import '../core/firebase_sync_base.dart';
import '../core/store/sync_object.dart';
import '../core/sync/conflict_resolver.dart';
import '../core/sync/sync_engine.dart';
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

  late final SodiumKeyManager keyManager = SodiumKeyManager(
    keySource: keySource,
    sodium: sodium,
  );

  @override
  late final SodiumDataEncryptor cryptoService = SodiumDataEncryptor(
    sodium: sodium,
    keyManager: keyManager,
  );

  @override
  final FirebaseStore<dynamic> rootStore;

  FirebaseSyncHive({
    required this.hive,
    required this.sodium,
    required this.keySource,
    required this.rootStore,
    int parallelJobs = SyncEngine.defaultParallelJobs,
  }) : super(
          parallelJobs: parallelJobs,
        );

  @override
  bool isStoreOpen(String name) => hive.isBoxOpen(name);

  @override
  Future<HiveSyncStore<T>> openStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required covariant TypeAdapter<T> storageConverter,
    SyncMode syncMode = SyncMode.sync, // TODO use
    ConflictResolver<T>? conflictResolver,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
    _registerTypeAdapter(storageConverter);

    final box = await hive.openBox<SyncObject<T>>(
      name,
      encryptionCipher: await _createCipher(name),
      keyComparator: keyComparator,
      compactionStrategy: compactionStrategy,
      crashRecovery: crashRecovery,
      path: path,
    );

    return HiveSyncStore(
      rawBox: box,
      uuid: sodium.uuid,
      syncNode: createSyncNode(
        storeName: name,
        localStore: HiveSyncObjectStore(box),
        jsonConverter: jsonConverter,
        conflictResolver: conflictResolver,
      ),
      closeCallback: () => closeSyncNode(name),
    );
  }

  Future<LazyHiveSyncStore<T>> openLazyStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required covariant TypeAdapter<T> storageConverter,
    SyncMode syncMode = SyncMode.sync, // TODO use
    ConflictResolver<T>? conflictResolver,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
    _registerTypeAdapter(storageConverter);

    final box = await hive.openLazyBox<SyncObject<T>>(
      name,
      encryptionCipher: await _createCipher(name),
      keyComparator: keyComparator,
      compactionStrategy: compactionStrategy,
      crashRecovery: crashRecovery,
      path: path,
    );

    return LazyHiveSyncStore(
      rawBox: box,
      uuid: sodium.uuid,
      syncNode: createSyncNode(
        storeName: name,
        localStore: LazyHiveSyncObjectStore(box),
        jsonConverter: jsonConverter,
        conflictResolver: conflictResolver,
      ),
      closeCallback: () => closeSyncNode(name),
    );
  }

  @override
  HiveSyncStore<T> store<T extends Object>(String name) {
    final syncNode = getSyncNode<T>(name);
    return HiveSyncStore(
      rawBox: hive.box(name),
      uuid: sodium.uuid,
      syncNode: syncNode,
      closeCallback: () => closeSyncNode(name),
    );
  }

  LazyHiveSyncStore<T> lazyStore<T extends Object>(String name) {
    final syncNode = getSyncNode<T>(name);
    return LazyHiveSyncStore(
      rawBox: hive.lazyBox(name),
      uuid: sodium.uuid,
      syncNode: syncNode,
      closeCallback: () => closeSyncNode(name),
    );
  }

  @override
  Future<HiveOfflineStore<T>> openOfflineStore<T extends Object>({
    required String name,
    required covariant TypeAdapter<T> storageConverter,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
    hive.registerAdapter(storageConverter);

    final box = await hive.openBox<T>(
      name,
      encryptionCipher: await _createCipher(name),
      keyComparator: keyComparator,
      compactionStrategy: compactionStrategy,
      crashRecovery: crashRecovery,
      path: path,
    );

    return HiveOfflineStore(box, sodium.uuid);
  }

  Future<LazyHiveOfflineStore<T>> openLazyOfflineStore<T extends Object>({
    required String name,
    required covariant TypeAdapter<T> storageConverter,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
    hive.registerAdapter(storageConverter);

    final box = await hive.openLazyBox<T>(
      name,
      encryptionCipher: await _createCipher(name),
      keyComparator: keyComparator,
      compactionStrategy: compactionStrategy,
      crashRecovery: crashRecovery,
      path: path,
    );

    return LazyHiveOfflineStore(box, sodium.uuid);
  }

  @override
  HiveOfflineStore<T> offlineStore<T extends Object>(String name) =>
      HiveOfflineStore(hive.box(name), sodium.uuid);

  LazyHiveOfflineStore<T> lazyOfflineStore<T extends Object>(String name) =>
      LazyHiveOfflineStore(hive.lazyBox(name), sodium.uuid);

  @override
  Future<void> close() async {
    await super.close();
    await hive.close();
  }

  void _registerTypeAdapter<T extends Object>(TypeAdapter<T> hiveAdapter) {
    hive.registerAdapter(
      SyncObjectAdapter<T>(hiveAdapter),
    );
  }

  Future<HiveCipher> _createCipher(String storeName) async => SodiumHiveCipher(
        sodium: sodium,
        encryptionKey: keyManager.localEncryptionKey(
          storeName: storeName,
          keyBytes: SodiumHiveCipher.keyBytes(sodium),
        ),
      );
}
