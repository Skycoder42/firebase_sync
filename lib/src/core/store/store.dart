import 'dart:async';

import 'store_base.dart';

abstract class Store<T extends Object> implements StoreBase<T> {
  const Store._(); // coverage:ignore-line

  FutureOr<int> count();

  FutureOr<Iterable<String>> listKeys();

  FutureOr<bool> contains(String key);

  FutureOr<void> put(String key, T value);

  FutureOr<void> delete(String key);

  FutureOr<void> clear();
}
