import 'dart:async';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import '../core/store/store.dart';

abstract class LazyHiveStore<T extends Object> implements Store<T> {
  @override
  Future<int> count();

  @override
  Future<Iterable<String>> listKeys();

  @override
  Future<Map<String, T>> listEntries();

  @override
  Future<bool> contains(String key);

  @override
  Future<T?> get(String key);

  @override
  Future<String> create(T value);

  @override
  Future<void> put(String key, T value);

  @override
  Future<T?> update(String key, UpdateFn<T> onUpdate);

  @override
  Future<void> delete(String key);

  @override
  Future<void> clear();

  Future<bool> get isEmpty;

  Future<bool> get isNotEmpty;

  bool get isOpen;

  bool get lazy;

  String get name;

  String? get path;

  Future<void> compact();

  Future<Iterable<T>> values();
}

@internal
extension LazyBoxLocksX on LazyBox<dynamic> {
  static late final _boxLocks = Expando<Lock>();

  Lock get lock => _boxLocks[this] ??= Lock();
}
