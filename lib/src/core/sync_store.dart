import 'store/store.dart';
import 'sync/sync_controller.dart';

abstract class SyncStore<T extends Object>
    implements Store<T>, SyncController<T> {
  const SyncStore._(); // coverage:ignore-line
}
