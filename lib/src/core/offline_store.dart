import 'store/store.dart';

abstract class OfflineStore<T extends Object> implements Store<T> {
  const OfflineStore._(); // coverage:ignore-line

  Future<void> close();

  Future<void> destroy();
}
