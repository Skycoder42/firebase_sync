import 'package:firebase_database_rest/firebase_database_rest.dart';

typedef StoreFactory<T> = FirebaseStore<T> Function(
  FirebaseStore<dynamic> parent,
  String path,
);

class NoStoreFactoryRegisteredError extends StateError {
  NoStoreFactoryRegisteredError(Type type)
      : super(
          'There was no FirebaseStore factory registered for '
          '${Error.safeToString(type)}',
        );
}

class FirebaseStoreFactory {
  final Map<Type, StoreFactory<dynamic>> _stores = {};

  FirebaseStoreFactory();

  void registerStore<T>(
    StoreFactory<T> storeFactory, {
    bool allowOverwrite = false,
  }) =>
      _stores.update(
        T,
        (value) => allowOverwrite ? storeFactory : value,
        ifAbsent: () => storeFactory,
      );

  FirebaseStore<T> createStore<T>(
    FirebaseStore<dynamic> parent,
    String path,
  ) {
    final factory = _stores[T] as StoreFactory<T>?;
    if (factory == null) {
      throw NoStoreFactoryRegisteredError(T);
    }
    return factory(parent, path);
  }
}
