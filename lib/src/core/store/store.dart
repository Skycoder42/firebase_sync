import 'dart:async';

import 'store_base.dart';
import 'store_event.dart';
import 'update_action.dart';

typedef UpdateFn<T extends Object> = UpdateAction<T> Function(T? oldValue);

abstract class Store<T extends Object> implements StoreBase<T> {
  const Store._();

  FutureOr<int> count();

  FutureOr<Iterable<String>> listKeys();

  FutureOr<Map<String, T>> listEntries();

  FutureOr<bool> contains(String key);

  FutureOr<T?> get(String key);

  FutureOr<void> put(String key, T value);

  FutureOr<UpdateResult<T>> update(
    String key,
    UpdateFn<T> onUpdate,
  );

  FutureOr<void> delete(String key);

  Stream<StoreEvent<T>> watch();
}
