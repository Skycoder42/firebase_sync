import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/storage/storage.dart';
import 'package:mocktail/mocktail.dart';

class FakeFilter extends Fake implements Filter {}

class FakeTransactionFn<T extends Object, TR> {
  final TR result;

  FakeTransactionFn(this.result);

  FutureOr<TR> call(Storage<T> storage) => result;
}

void registerFakes() {
  registerFallbackValue<Filter>(FakeFilter());
}
