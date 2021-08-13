import '../core/store/store.dart';

abstract class HiveStore<T extends Object> implements Store<T> {
  const HiveStore._();

  @override
  int count();

  @override
  Iterable<String> listKeys();

  @override
  Map<String, T> listEntries();

  @override
  bool contains(String key);

  @override
  T? get(String key);

  @override
  String create(T value);

  @override
  void put(String key, T value);

  @override
  T? update(String key, UpdateFn<T> onUpdate);

  @override
  void delete(String key);

  @override
  void clear();

  bool get isEmpty;

  bool get isNotEmpty;

  bool get isOpen;

  bool get lazy;

  String get name;

  String? get path;

  Future<void> compact();

  Iterable<T> get values;

  Iterable<T> valuesBetween({
    String? startKey,
    String? endKey,
  });
}
