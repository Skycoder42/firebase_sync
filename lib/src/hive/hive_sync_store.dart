import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../core/store/sync_object.dart';
import '../core/sync/sync_controller_mixin.dart';
import '../core/sync/sync_mode.dart';
import '../core/sync/sync_node.dart';
import '../core/sync_store.dart';
import 'hive_online_store.dart';
import 'lazy_hive_online_store.dart';

class HiveSyncStore<T extends Object> extends HiveOnlineStore<T>
    with SyncControllerMixin<T>
    implements SyncStore<T> {
  @internal
  final void Function() onClose;

  @override
  @internal
  final SyncNode<T> syncNode;

  HiveSyncStore({
    required Box<SyncObject<T>> rawBox,
    required Uuid uuid,
    required this.syncNode,
    required this.onClose,
  }) : super(rawBox, uuid);

  @override
  @mustCallSuper
  Future<void> destroy() async {
    onClose();
    await setSyncMode(SyncMode.none);
    await syncNode.close();
    await destroyRemote();
    await super.destroy();
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    onClose();
    await syncNode.close();
    await super.close();
  }
}

class LazyHiveSyncStore<T extends Object> extends LazyHiveOnlineStore<T>
    with SyncControllerMixin<T>
    implements SyncStore<T> {
  @internal
  final void Function() onClosed;

  @override
  @internal
  final SyncNode<T> syncNode;

  LazyHiveSyncStore({
    required LazyBox<SyncObject<T>> rawBox,
    required Uuid uuid,
    required this.syncNode,
    required this.onClosed,
  }) : super(rawBox, uuid);

  @override
  @mustCallSuper
  Future<void> destroy() async {
    onClosed();
    await setSyncMode(SyncMode.none);
    await syncNode.close();
    await destroyRemote();
    await super.destroy();
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    onClosed();
    await syncNode.close();
    await super.close();
  }
}
