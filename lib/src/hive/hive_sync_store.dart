import 'package:hive/hive.dart';
import 'package:meta/meta.dart';

import '../core/store/sync_object.dart';
import '../core/sync/sync_controller_mixin.dart';
import '../core/sync/sync_node.dart';
import '../core/sync_store.dart';
import 'hive_store.dart';
import 'lazy_hive_store.dart';

class HiveSyncStore<T extends Object> extends HiveStore<T>
    with SyncControllerMixin<T>
    implements SyncStore<T> {
  @override
  @internal
  final SyncNode<T> syncNode;

  HiveSyncStore({
    required Box<SyncObject<T>> rawBox,
    required this.syncNode,
  }) : super(rawBox, syncNode.boundKeyHasher);

  @override
  Future<void> close() async {
    // TODO close sync node
    await closeBox();
  }
}

class LazyHiveSyncStore<T extends Object> extends LazyHiveStore<T>
    with SyncControllerMixin<T>
    implements SyncStore<T> {
  @override
  @internal
  final SyncNode<T> syncNode;

  LazyHiveSyncStore({
    required LazyBox<SyncObject<T>> rawBox,
    required this.syncNode,
  }) : super(rawBox, syncNode.boundKeyHasher);

  @override
  Future<void> close() async {
    // TODO close sync node
    await closeBox();
  }
}
