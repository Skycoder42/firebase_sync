import 'dart:async';

import 'store_event.dart';
import 'sync_object.dart';
import 'update_action.dart';

typedef UpdateFn<T extends Object> = UpdateAction<SyncObject<T>> Function(
  SyncObject<T>? oldValue,
);

abstract class SyncObjectStore<T extends Object> {
  const SyncObjectStore._(); // coverage:ignore-line

  Iterable<String> get rawKeys;

  FutureOr<Map<String, SyncObject<T>>> listEntries();

  FutureOr<SyncObject<T>?> get(String key);

  FutureOr<SyncObject<T>?> update(String key, UpdateFn<T> onUpdate);

  Stream<StoreEvent<SyncObject<T>>> watch();
}
