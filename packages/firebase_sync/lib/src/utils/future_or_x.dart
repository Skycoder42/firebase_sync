import 'dart:async';

import 'package:meta/meta.dart';

@internal
extension FutureOrX<T> on FutureOr<T> {
  Future<T> toFuture() {
    if (this is Future<T>) {
      return this as Future<T>;
    } else {
      return Future.value(this as T);
    }
  }

  FutureOr<TR> then<TR>(FutureOr<TR> Function(T) next) {
    if (this is Future<T>) {
      return (this as Future<T>).then(next);
    } else {
      return next(this as T);
    }
  }

  T get sync {
    assert(
      this is T,
      'Cannot use FutureOrX.sync with asynchronous storages',
    );
    return this as T;
  }
}
