import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import 'sync_controller.dart';
import 'sync_mode.dart';
import 'sync_node.dart';

mixin SyncControllerMixin<T extends Object> implements SyncController<T> {
  @visibleForOverriding
  SyncNode<T> get syncNode;

  SyncMode _syncMode = SyncMode.none;

  @override
  SyncMode get syncMode => _syncMode;

  @override
  set syncMode(SyncMode syncMode) {
    // TODO: implement set syncMode
    throw UnimplementedError();
  }

  @override
  Future<int> download([Filter? filter]) {
    // TODO: implement download
    throw UnimplementedError();
  }

  @override
  Future<int> upload({bool multipass = true}) {
    // TODO: implement upload
    throw UnimplementedError();
  }

  @override
  Future<int> reload({Filter? filter, bool multipass = true}) {
    // TODO: implement reload
    throw UnimplementedError();
  }

  @override
  Future<MapEntry<String, T>> create(T value) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  Future<void> destroy() {
    // TODO: implement destroy
    throw UnimplementedError();
  }
}
