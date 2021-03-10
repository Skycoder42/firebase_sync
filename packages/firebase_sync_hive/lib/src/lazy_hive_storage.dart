import 'dart:async';

import 'package:hive/hive.dart';

import 'hive_storage_base.dart';

class LazyHiveStorage<T> extends HiveStorageBase<T> {
  LazyHiveStorage({
    required LazyBox<T> box,
    bool awaitBoxOperations = false,
  }) : super(
          box: box,
          awaitBoxOperations: awaitBoxOperations,
        );

  @override
  LazyBox<T> get box => super.box as LazyBox<T>;

  @override
  bool get isSync => false;

  @override
  FutureOr<Map<String, T>> entries() async {
    final allEntries = await Future.wait(
      box.keys
          .cast<String>()
          .map((key) async => MapEntry(key, await box.get(key))),
      eagerError: true,
    );
    return Map.fromEntries(
      allEntries.where((entry) => entry.value != null).cast(),
    );
  }

  @override
  FutureOr<T?> readEntry(String key) => box.get(key);
}
