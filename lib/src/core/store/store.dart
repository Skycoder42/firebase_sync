import 'dart:async';

import 'store_event.dart';
import 'update_action.dart';

typedef UpdateFn<T extends Object> = UpdateAction<T> Function(T? oldValue);

abstract class Store<T extends Object> {
  const Store._(); // coverage:ignore-line

  FutureOr<int> count();

  FutureOr<Iterable<String>> listKeys();

  FutureOr<Map<String, T>> listEntries();

  FutureOr<bool> contains(String key);

  FutureOr<T?> get(String key);

  FutureOr<void> put(String key, T value);

  FutureOr<T?> update(
    String key,
    UpdateFn<T> onUpdate,
  );

  FutureOr<void> delete(String key);

  FutureOr<void> clear();

  Stream<StoreEvent<T>> watch();
}
