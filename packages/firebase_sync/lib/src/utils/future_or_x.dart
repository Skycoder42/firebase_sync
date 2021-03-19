import 'dart:async';

import 'package:meta/meta.dart';

typedef ThenFn<T, TR> = FutureOr<TR> Function(T value);

@internal
extension FutureOrX<T> on FutureOr<T> {
  Future<T> toFuture() {
    if (this is Future<T>) {
      return this as Future<T>;
    } else {
      return Future.value(this as T);
    }
  }

  FutureOr<TR> then<TR>(ThenFn<T, TR> next) {
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

extension FutureOrIterableX<T> on FutureOr<Iterable<T>> {
  FutureOr<Iterable<TR>> forEach<TR>(ThenFn<T, TR> next) => then((oldValues) {
        var needsAwait = false;
        final newValues = oldValues.map((oldValue) {
          final newValue = next(oldValue);
          if (!needsAwait && newValue is Future<TR>) {
            needsAwait = true;
          }
          return newValue;
        });
        if (needsAwait) {
          return Future.wait(
            newValues.map((e) => e.toFuture()),
            eagerError: true,
          );
        } else {
          return newValues.map((e) => e.sync);
        }
      });
}
