import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../core/store/sync_object.dart';
import '../core/sync/sync_controller_mixin.dart';
import '../core/sync/sync_node.dart';
import '../core/sync_store.dart';
import 'hive_online_store.dart';
import 'lazy_hive_online_store.dart';

class HiveSyncStore<T extends Object> extends HiveOnlineStore<T>
    with SyncControllerMixin<T>
    implements SyncStore<T> {
  @internal
  final void Function() closeCallback;

  @override
  @internal
  final SyncNode<T> syncNode;

  HiveSyncStore({
    required Box<SyncObject<T>> rawBox,
    required Uuid uuid,
    required this.syncNode,
    required this.closeCallback,
  }) : super(rawBox, uuid);

  @override
  Future<void> destroy() async {
    closeCallback();
    await destroyNode();
    await destroyBox();
  }

  @override
  Future<void> close() async {
    closeCallback();
    await closeBox();
  }
}

class LazyHiveSyncStore<T extends Object> extends LazyHiveOnlineStore<T>
    with SyncControllerMixin<T>
    implements SyncStore<T> {
  @internal
  final void Function() closeCallback;

  @override
  @internal
  final SyncNode<T> syncNode;

  LazyHiveSyncStore({
    required LazyBox<SyncObject<T>> rawBox,
    required Uuid uuid,
    required this.syncNode,
    required this.closeCallback,
  }) : super(rawBox, uuid);

  @override
  Future<void> destroy() async {
    closeCallback();
    await destroyNode();
    await destroyBox();
  }

  @override
  Future<void> close() async {
    closeCallback();
    await closeBox();
  }
}
