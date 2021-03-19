import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../local_store_event.dart';
import '../utils/future_or_x.dart';
import 'storage.dart';

class JsonStorage<T extends Object> implements Storage<T> {
  final Storage<dynamic> rawStorage;
  final JsonConverter<T> jsonConverter;

  const JsonStorage({
    required this.rawStorage,
    required this.jsonConverter,
  });

  @override
  bool get isSync => rawStorage.isSync;

  @override
  FutureOr<int> length() => rawStorage.length();

  @override
  FutureOr<Iterable<String>> keys() => rawStorage.keys();

  @override
  FutureOr<Map<String, T>> entries() =>
      rawStorage.entries().then((entries) => entries.map(
            (key, dynamic value) => MapEntry(
              key,
              jsonConverter.dataFromJson(value),
            ),
          ));

  @override
  FutureOr<bool> contains(String key) => rawStorage.contains(key);

  @override
  FutureOr<T?> readEntry(String key) => rawStorage.readEntry(key).then(
        (dynamic value) =>
            value != null ? jsonConverter.dataFromJson(value) : null,
      );

  @override
  Stream<LocalStoreEvent<T>> watch() => rawStorage.watch().map(
        (event) => event.when(
          update: (key, dynamic value) => LocalStoreEvent.update(
            key,
            jsonConverter.dataFromJson(value),
          ),
          delete: (key) => LocalStoreEvent.delete(key),
        ),
      );

  @override
  Stream<T?> watchEntry(String key) => rawStorage.watchEntry(key).map(
        (dynamic value) =>
            value != null ? jsonConverter.dataFromJson(value) : null,
      );

  @override
  FutureOr<void> writeEntry(String key, T value) =>
      rawStorage.writeEntry(key, jsonConverter.dataToJson(value));

  @override
  FutureOr<void> writeEntries(Map<String, T> entries) =>
      rawStorage.writeEntries(entries.map<String, dynamic>(
        (key, value) => MapEntry<String, dynamic>(
          key,
          jsonConverter.dataToJson(value),
        ),
      ));

  @override
  FutureOr<void> deleteEntry(String key) => rawStorage.deleteEntry(key);

  @override
  FutureOr<void> deleteEntries(Iterable<String> keys) =>
      rawStorage.deleteEntries(keys);

  @override
  FutureOr<void> clear() => rawStorage.clear();

  @override
  FutureOr<void> destroy() => rawStorage.destroy();

  @override
  FutureOr<TR> transaction<TR>(TransactionFn<T, TR> transactionCallback) =>
      rawStorage.transaction((storage) => transactionCallback(JsonStorage(
            rawStorage: storage,
            jsonConverter: jsonConverter,
          )));

  @override
  Future<void> close() => rawStorage.close();
}
