import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';

import '../local_store_event.dart';
import '../storage/storage.dart';
import '../store_transaction.dart';
import '../utils/future_or_x.dart';
import '../utils/read_only_store_transaction.dart';
import 'local_read_store.dart';
import 'local_read_store_sync.dart';
import 'read_only_store_sync.dart';

enum ReloadStrategy {
  clear,
  compareKey,
  compareValue,
}

class ReadOnlyStore<T extends Object> implements LocalReadStore<T> {
  final FirebaseStore<T> firebaseStore;
  final Storage<T> storage;

  ReloadStrategy reloadStrategy = ReloadStrategy.compareKey;

  ReadOnlyStore({
    required this.firebaseStore,
    required this.storage,
  });

  LocalReadStoreSync<T> syncReader() => ReadOnlyStoreSync<T>(storage);

  // local
  @override
  Future<int> length() => storage.length().toFuture();

  @override
  Future<bool> isEmpty() {
    final length = storage.length();
    if (length is Future<int>) {
      return length.then((value) => value == 0);
    } else {
      return Future.value(length == 0);
    }
  }

  @override
  Future<bool> isNotEmpty() {
    final length = storage.length();
    if (length is Future<int>) {
      return length.then((value) => value != 0);
    } else {
      return Future.value(length != 0);
    }
  }

  @override
  Future<List<String>> keys() => storage.keys().toFuture();

  @override
  Future<Map<String, T>> asMap() => storage.entries().toFuture();

  @override
  Future<bool> contains(String key) => storage.contains(key).toFuture();

  @override
  Future<T?> value(String key) => storage.readEntry(key).toFuture();

  @override
  Future<Stream<LocalStoreEvent<T>>> watch() => storage.watch().toFuture();

  @override
  Future<Stream<T?>> watchEntry(String key) =>
      storage.watchEntry(key).toFuture();

  @override
  Future<void> clear() => storage.clear().toFuture();

  // remote
  Future<void> reload([Filter? filter]) async {
    final newEntries = await (filter != null
        ? firebaseStore.query(filter)
        : firebaseStore.all());
    await _reset(newEntries);
  }

  Future<StreamSubscription<void>> sync({
    Filter? filter,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) async {
    final stream = await (filter != null
        ? firebaseStore.streamQuery(filter)
        : firebaseStore.streamAll());
    return stream.asyncMap(_handleStreamEvent).listen(
          null,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }

  StreamSubscription<void> syncRenewed({
    FutureOr<Filter> Function()? onRenewFilter,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) =>
      AutoRenewStream(() async {
        final filter = await onRenewFilter?.call();
        return filter != null
            ? firebaseStore.streamQuery(filter)
            : firebaseStore.streamAll();
      }).asyncMap(_handleStreamEvent).listen(
            null,
            onError: onError,
            onDone: onDone,
            cancelOnError: cancelOnError,
          );

  Future<T?> fetch(String key) async {
    final value = await firebaseStore.read(key);
    if (value != null) {
      await storage.writeEntry(key, value);
    } else {
      await storage.deleteEntry(key);
    }
    return value;
  }

  Future<String> create(T value) async {
    final key = await firebaseStore.create(value);
    await storage.writeEntry(key, value);
    return key;
  }

  Future<void> store(String key, T value) async {
    await firebaseStore.write(key, value, silent: true);
    await storage.writeEntry(key, value);
  }

  Future<T?> patch(String key, Map<String, dynamic> updateFields) async {
    final value = await firebaseStore.update(
      key,
      updateFields,
      currentData: await storage.readEntry(key),
    );
    if (value != null) {
      await storage.writeEntry(key, value);
    } else {
      await storage.deleteEntry(key);
    }
    return value;
  }

  Future<void> remove(String key) async {
    await firebaseStore.delete(key);
    await storage.deleteEntry(key);
  }

  Future<StoreTransaction<T>> transaction(String key) async {
    final transaction = await firebaseStore.transaction(key);
    if (transaction.value != null) {
      await storage.writeEntry(key, transaction.value!);
    } else {
      await storage.deleteEntry(key);
    }
    return ReadOnlyStoreTransaction(
      storage,
      await firebaseStore.transaction(key),
    );
  }

  FutureOr<void> _handleStreamEvent(StoreEvent<T> event) =>
      event.when<FutureOr<void>>(
        reset: (data) => _reset(data),
        put: (key, value) => storage.writeEntry(key, value),
        delete: (key) => storage.deleteEntry(key),
        patch: (key, patchSet) async {
          final currentValue = await storage.readEntry(key);
          if (currentValue != null) {
            await storage.writeEntry(key, patchSet.apply(currentValue));
          }
        },
        // ignore: void_checks
        invalidPath: (path) {
          throw UnimplementedError('invalidPath has not been implemented yet');
        },
      );

  Future<void> _reset(Map<String, T> entries) async {
    switch (reloadStrategy) {
      case ReloadStrategy.clear:
        await storage.transaction((storage) async {
          await storage.clear();
          await storage.writeEntries(entries);
        });
        break;
      case ReloadStrategy.compareKey:
        await storage.transaction((storage) async {
          final oldKeys = (await storage.keys()).toSet();
          final deletedKeys = oldKeys.difference(entries.keys.toSet());
          await storage.writeEntries(entries);
          await storage.deleteEntries(deletedKeys);
        });
        break;
      case ReloadStrategy.compareValue:
        await storage.transaction((storage) async {
          final oldKeys = (await storage.keys()).toSet();
          final deletedKeys = oldKeys.difference(entries.keys.toSet());
          final filteredEntries = await _filterByValue(storage, entries);
          await storage.writeEntries(filteredEntries);
          await storage.deleteEntries(deletedKeys);
        });
        break;
    }
  }

  static FutureOr<Map<String, T>> _filterByValue<T extends Object>(
    Storage<T> storage,
    Map<String, T> entries,
  ) async {
    final values = <String, T>{};
    for (final entry in entries.entries) {
      final currentValue = await storage.readEntry(entry.key);
      if (currentValue != entry.value) {
        values[entry.key] = entry.value;
      }
    }
    return values;
  }
}
