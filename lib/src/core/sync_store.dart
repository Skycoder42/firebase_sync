import 'package:firebase_sync/src/core/sync/sync_controller.dart';

import 'store/store.dart';

abstract class SyncStore<T extends Object>
    implements Store<T>, SyncController<T> {
  const SyncStore._();

  Future<void> close();
}
