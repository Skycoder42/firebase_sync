import 'store_base.dart';
import 'sync_object.dart';

abstract class SyncObjectStore<T extends Object>
    implements StoreBase<SyncObject<T>> {
  const SyncObjectStore._(); // coverage:ignore-line

  Iterable<String> get rawKeys;
}
