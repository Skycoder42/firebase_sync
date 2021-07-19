import 'dart:async';

import 'store_event.dart';
import 'update_action.dart';

typedef UpdateFn<T extends Object> = UpdateAction<T> Function(T? oldValue);

abstract class StoreBase<T extends Object> {
  const StoreBase._();

  FutureOr<Map<String, T>> listEntries();

  FutureOr<T?> get(String key);

  FutureOr<T?> update(
    String key,
    UpdateFn<T> onUpdate,
  );

  Stream<StoreEvent<T>> watch();
}
