import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/sodium/key_controller.dart';
import 'package:firebase_sync/src/sodium/sodium_crypto_service.dart';
import 'package:firebase_sync/src/sodium/sodium_key_manager.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/box/default_compaction_strategy.dart';
// ignore: implementation_imports
import 'package:hive/src/box/default_key_comparator.dart';
import 'package:sodium/sodium.dart';

import '../core/firebase_sync_base.dart';
import '../core/store/sync_object.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_mode.dart';
import 'crypto/sodium_hive_cipher.dart';
import 'hive_sync_object_store.dart';
import 'hive_sync_store.dart';

class FirebaseSyncHive extends FirebaseSyncBase {
  final HiveInterface hive;
  final Sodium sodium;
  final KeyController keyController;

  late final SodiumKeyManager keyManager = SodiumKeyManager(
    keyController: keyController,
    sodium: sodium,
  );

  @override
  late final SodiumCryptoService cryptoService = SodiumCryptoService(
    sodium: sodium,
    keyManager: keyManager,
  );

  @override
  final FirebaseStore<dynamic> rootStore;

  FirebaseSyncHive({
    required this.hive,
    required this.sodium,
    required this.keyController,
    required this.rootStore,
    int parallelJobs = SyncEngine.defaultParallelJobs,
    bool startSync = true,
  }) : super(
          parallelJobs: parallelJobs,
          startSync: startSync,
        );

  @override
  bool isStoreOpen(String name) => hive.isBoxOpen(name);

  @override
  Future<HiveSyncStore<T>> openStore<T extends Object>(
    String name, {
    SyncMode syncMode = SyncMode.sync,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
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
      syncNode: createSyncNode(
        name,
        HiveSyncObjectStore(box),
      ),
    );
  }

  Future<LazyHiveSyncStore<T>> openLazyStore<T extends Object>(
    String name, {
    SyncMode syncMode = SyncMode.sync,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
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
      syncNode: createSyncNode(
        name,
        LazyHiveSyncObjectStore(box),
      ),
    );
  }

  @override
  HiveSyncStore<T> store<T extends Object>(String name) => HiveSyncStore(
        rawBox: hive.box(name),
        syncNode: getSyncNode(name),
      );

  LazyHiveSyncStore<T> lazyStore<T extends Object>(String name) =>
      LazyHiveSyncStore(
        rawBox: hive.lazyBox(name),
        syncNode: getSyncNode(name),
      );

  @override
  Future<void> close() async {
    await super.close();
    await hive.close();
  }

  @override
  void registerConverter<T extends Object>({
    required JsonConverter<T> converter,
    ConflictResolver<T>? conflictResolver,
    bool override = false,
    TypeAdapter<T>? hiveAdapter,
  }) {
    super.registerConverter(
      converter: converter,
      conflictResolver: conflictResolver,
      override: override,
    );
    if (hiveAdapter != null) {
      hive.registerAdapter(
        hiveAdapter,
        override: override,
      );
    }
  }

  Future<HiveCipher> _createCipher(String storeName) async => SodiumHiveCipher(
        sodium: sodium,
        encryptionKey: keyManager.localEncryptionKey(
          storeName: storeName,
          keyBytes: SodiumHiveCipher.keyBytes(sodium),
        ),
      );
}
