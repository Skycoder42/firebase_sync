abstract class StoreTransaction<T> {
  const StoreTransaction._();

  String get key;

  T? get value;

  Future<T?> commitUpdate(T data);

  Future<void> commitDelete();

  void abort();
}
