import '../../firebase_sync.dart';
import '../local_store_event.dart';

abstract class ReadStoreLocalSync<T extends Object> {
  const ReadStoreLocalSync._();

  int get length;

  bool get isEmpty;

  bool get isNotEmpty;

  Iterable<String> get keys;

  Map<String, T> asMap();

  bool contains(String key);

  T? value(String key);

  Stream<LocalStoreEvent<T>> watch();

  Stream<T?> watchEntry(String key);

  T? operator [](String key);

  void clear();
}
