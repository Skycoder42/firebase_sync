import 'dart:async';

import 'package:meta/meta.dart';

@internal
extension FutureOrX<T> on FutureOr<T> {
  Future<T> toFuture() {
    if (this is Future<T>) {
      return this as Future<T>;
    } else {
      return Future.value(this);
    }
  }

  T get sync {
    assert(
      this is T,
      'Cannot use ReadOnlyStoreSyncReader with asynchronous storages',
    );
    return this as T;
  }
}
