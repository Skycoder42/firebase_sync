import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_database_rest/rest.dart';

import 'crypto_data.dart';
import 'store_entry_cryptor.dart';

class FirebaseCryptoStore<T extends Object> implements FirebaseStore<T> {
  final FirebaseStore<CryptoData> rawStore;
  final StoreEntryCryptor cryptor;

  const FirebaseCryptoStore({
    required this.rawStore,
    required this.cryptor,
  });

  @override
  RestApi get restApi => rawStore.restApi;

  @override
  List<String> get subPaths => rawStore.subPaths;

  @override
  String get path => rawStore.path;

  @override
  FirebaseStore<U> subStore<U>({
    required String path,
    required DataFromJsonCallback<U> onDataFromJson,
    required DataToJsonCallback<U> onDataToJson,
    required PatchDataCallback<U> onPatchData,
  }) {
    // TODO: implement subStore
    throw UnimplementedError();
  }

  @override
  Future<List<String>> keys({ETagReceiver? eTagReceiver}) =>
      rawStore.keys(eTagReceiver: eTagReceiver);

  @override
  Future<Map<String, T>> all({ETagReceiver? eTagReceiver}) async {
    final encryptedEntries = await rawStore.all(eTagReceiver: eTagReceiver);
    return Map.fromEntries(
      await Stream.fromIterable(encryptedEntries.entries)
          .asyncMap(
            (entry) async => MapEntry(
              entry.key,
              await cryptor.decrypt(
                cryptoData: entry.value,
                keyPath: _keyPath(entry.key),
              ) as Map<String, dynamic>?,
            ),
          )
          .where((entry) => entry.value != null)
          .map(
            (entry) => MapEntry(
              entry.key,
              dataFromJson(entry.value),
            ),
          )
          .toList(),
    );
  }

  // --- seperator ---

  @override
  Future<String> create(T data, {ETagReceiver? eTagReceiver}) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  T dataFromJson(dynamic json) {
    // TODO: implement dataFromJson
    throw UnimplementedError();
  }

  @override
  dynamic dataToJson(T data) {
    // TODO: implement dataToJson
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String key, {String? eTag, ETagReceiver? eTagReceiver}) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<void> destroy({String? eTag, ETagReceiver? eTagReceiver}) {
    // TODO: implement destroy
    throw UnimplementedError();
  }

  @override
  Map<String, T> mapTransform(
    dynamic data,
    DataFromJsonCallback<T> dataFromJson,
  ) {
    // TODO: implement mapTransform
    throw UnimplementedError();
  }

  @override
  T patchData(T data, Map<String, dynamic> updatedFields) {
    // TODO: implement patchData
    throw UnimplementedError();
  }

  @override
  Future<Map<String, T>> query(Filter filter) {
    // TODO: implement query
    throw UnimplementedError();
  }

  @override
  Future<List<String>> queryKeys(Filter filter) {
    // TODO: implement queryKeys
    throw UnimplementedError();
  }

  @override
  Future<T?> read(String key, {ETagReceiver? eTagReceiver}) {
    // TODO: implement read
    throw UnimplementedError();
  }

  @override
  Future<Stream<StoreEvent<T>>> streamAll() {
    // TODO: implement streamAll
    throw UnimplementedError();
  }

  @override
  Future<Stream<ValueEvent<T>>> streamEntry(String key) {
    // TODO: implement streamEntry
    throw UnimplementedError();
  }

  @override
  Future<Stream<KeyEvent>> streamKeys() {
    // TODO: implement streamKeys
    throw UnimplementedError();
  }

  @override
  Future<Stream<StoreEvent<T>>> streamQuery(Filter filter) {
    // TODO: implement streamQuery
    throw UnimplementedError();
  }

  @override
  Future<Stream<KeyEvent>> streamQueryKeys(Filter filter) {
    // TODO: implement streamQueryKeys
    throw UnimplementedError();
  }

  @override
  Future<FirebaseTransaction<T>> transaction(String key,
      {ETagReceiver? eTagReceiver}) {
    // TODO: implement transaction
    throw UnimplementedError();
  }

  @override
  Future<T?> update(String key, Map<String, dynamic> updateFields,
      {T? currentData}) {
    // TODO: implement update
    throw UnimplementedError();
  }

  @override
  Future<T?> write(String key, T data,
      {bool silent = false, String? eTag, ETagReceiver? eTagReceiver}) {
    // TODO: implement write
    throw UnimplementedError();
  }

  Iterable<String> _keyPath(String key) =>
      [rawStore.restApi.basePath, ...rawStore.subPaths, key];
}
