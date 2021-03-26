import 'dart:async';

import 'package:firebase_sync/src/utils/future_or_x.dart';
import 'package:test/test.dart';

void main() {
  group('toFuture', () {
    test('returns a future', () {
      final FutureOr<int> future = Future.value(42);
      final res = future.toFuture();
      expect(res, same(future));
    });

    test('wraps a normal value', () {
      const FutureOr<int> value = 42;
      final res = value.toFuture();
      expect(res.timeout(Duration.zero), completion(value));
    });
  });

  group('then', () {
    test('chains future calls', () {
      final FutureOr<int> future = Future.value(42);
      final res = future.then((value) => Future.value(value * 2));
      expect(res, completion(84));
    });

    test('calls values immediatly', () {
      const FutureOr<int> value = 42;
      final res = value.then((value) => value * 2);
      expect(res, 84);
    });
  });

  group('sync', () {
    test('asserts if it is a future', () {
      final FutureOr<int> value = Future.value(42);
      expect(() => value.sync, throwsA(isA<AssertionError>()));
    });

    test('returns values', () {
      const FutureOr<int> value = 42;
      final res = value.sync;
      expect(res, value);
    });
  });

  group('forEach', () {
    test('applies next async to all values', () {
      final FutureOr<List<int>> values = Future.value([1, 2, 3, 4, 5]);
      final res = values.forEach((value) => Future.value(value * 2));
      expect(res, completion([2, 4, 6, 8, 10]));
    });

    test('applies next sync to all values', () {
      const FutureOr<List<int>> values = [1, 2, 3, 4, 5];
      final res = values.forEach((value) => value * 2);
      expect(res, const [2, 4, 6, 8, 10]);
    });
  });
}
