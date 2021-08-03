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
import '../sodium/key_controller.dart';
import '../sodium/sodium_data_encryptor.dart';
import '../sodium/sodium_key_hasher.dart';
import '../sodium/sodium_key_manager.dart';
import 'crypto/sodium_hive_cipher.dart';
import 'hive_sync_object_store.dart';
import 'hive_sync_store.dart';
import 'sync_object_adapter.dart';

class FirebaseSyncHive extends FirebaseSyncBase {
  final HiveInterface hive;
  final Sodium sodium;
  final KeyController keyController;

  late final SodiumKeyManager keyManager = SodiumKeyManager(
    keyController: keyController,
    sodium: sodium,
  );

  @override
  late final SodiumDataEncryptor cryptoService = SodiumDataEncryptor(
    sodium: sodium,
    keyManager: keyManager,
  );

  @override
  late final SodiumKeyHasher keyHasher = SodiumKeyHasher(
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
    bool hashKeys = false,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
    _registerTypeAdapter(
      hiveAdapter: storageConverter,
      hashKeys: hashKeys,
    );

    final box = await hive.openBox<SyncObject<T>>(
      _boxName(name, hashed: hashKeys),
      encryptionCipher: await _createCipher(name),
      keyComparator: keyComparator,
      compactionStrategy: compactionStrategy,
      crashRecovery: crashRecovery,
      path: path,
    );

    return HiveSyncStore(
      rawBox: box,
      syncNode: createSyncNode(
        storeName: name,
        localStore: HiveSyncObjectStore(box),
        jsonConverter: jsonConverter,
        keyHasher: hashKeys ? keyHasher : null,
        conflictResolver: conflictResolver,
      ),
    );
  }

  Future<LazyHiveSyncStore<T>> openLazyStore<T extends Object>({
    required String name,
    required JsonConverter<T> jsonConverter,
    required covariant TypeAdapter<T> storageConverter,
    SyncMode syncMode = SyncMode.sync, // TODO use
    ConflictResolver<T>? conflictResolver,
    bool hashKeys = false,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
  }) async {
    _registerTypeAdapter(
      hiveAdapter: storageConverter,
      hashKeys: hashKeys,
    );

    final box = await hive.openLazyBox<SyncObject<T>>(
      _boxName(name, hashed: hashKeys),
      encryptionCipher: await _createCipher(name),
      keyComparator: keyComparator,
      compactionStrategy: compactionStrategy,
      crashRecovery: crashRecovery,
      path: path,
    );

    return LazyHiveSyncStore(
      rawBox: box,
      syncNode: createSyncNode(
        storeName: name,
        localStore: LazyHiveSyncObjectStore(box),
        jsonConverter: jsonConverter,
        keyHasher: hashKeys ? keyHasher : null,
        conflictResolver: conflictResolver,
      ),
    );
  }

  @override
  HiveSyncStore<T> store<T extends Object>(String name) {
    final syncNode = getSyncNode<T>(name);
    return HiveSyncStore(
      rawBox: hive.box(_boxName(name, hashed: syncNode.keyHasher != null)),
      syncNode: syncNode,
    );
  }

  LazyHiveSyncStore<T> lazyStore<T extends Object>(String name) {
    final syncNode = getSyncNode<T>(name);
    return LazyHiveSyncStore(
      rawBox: hive.lazyBox(_boxName(name, hashed: syncNode.keyHasher != null)),
      syncNode: syncNode,
    );
  }

  @override
  Future<void> close() async {
    await super.close();
    await hive.close();
  }

  void _registerTypeAdapter<T extends Object>({
    required TypeAdapter<T> hiveAdapter,
    bool hashKeys = false,
  }) {
    hive.registerAdapter(
      SyncObjectAdapter<T>(
        contentAdapter: hiveAdapter,
        writePlainKeys: hashKeys,
      ),
    );
  }

  String _boxName(String storeName, {required bool hashed}) => hashed
      ? keyHasher.hashKey(
          storeName: storeName,
          key: storeName,
        )
      : storeName;

  Future<HiveCipher> _createCipher(String storeName) async => SodiumHiveCipher(
        sodium: sodium,
        encryptionKey: keyManager.localEncryptionKey(
          storeName: storeName,
          keyBytes: SodiumHiveCipher.keyBytes(sodium),
        ),
      );
}
