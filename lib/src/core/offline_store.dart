import 'store/store.dart';

abstract class OfflineStore<T extends Object> implements Store<T> {
  const OfflineStore._(); // coverage:ignore-line
}
