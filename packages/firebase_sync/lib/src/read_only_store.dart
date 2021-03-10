import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import 'read_only_store_sync_reader.dart';
import 'storage.dart';
import 'store_transaction.dart';
import 'utils/future_or_x.dart';
import 'utils/read_only_store_transaction.dart';
import 'utils/read_write_lock.dart';

enum ReloadStrategy {
  clear,
  compareKey,
  compareValue,
}

class ReadOnlyStore<T> {
  final FirebaseStore<T> firebaseStore;
  final Storage<T> storage;

  final _lock = ReadWriteLock();

  ReloadStrategy reloadStrategy = ReloadStrategy.compareKey;

  ReadOnlyStore({
    required this.firebaseStore,
    required this.storage,
  });

  ReadOnlyStoreSyncReader<T> syncReader() => ReadOnlyStoreSyncReader<T>(this);

  // local
  Future<int> length() => storage.length().toFuture();

  Future<bool> isEmpty() {
    final length = storage.length();
    if (length is Future<int>) {
      return length.then((value) => value == 0);
    } else {
      return Future.value(length == 0);
    }
  }

  Future<bool> isNotEmpty() {
    final length = storage.length();
    if (length is Future<int>) {
      return length.then((value) => value != 0);
    } else {
      return Future.value(length != 0);
    }
  }

  Future<List<String>> keys() => storage.keys().toFuture();

  Future<Map<String, T>> asMap() => storage.entries().toFuture();

  Future<bool> contains(String key) => storage.contains(key).toFuture();

  Future<T?> value(String key) => storage.readEntry(key).toFuture();

  Future<T?> operator [](String key) => storage.readEntry(key).toFuture();

  // TODO typed
  Future<Stream<dynamic>> watch() => storage.watch().toFuture();

  // TODO typed
  Future<Stream<dynamic>> watchEntry(String key) =>
      storage.watchEntry(key).toFuture();

  Future<void> clear() => _lock.runWriteLocked(storage.clear);

  // remote
  Future<void> reload([Filter? filter]) => _lock.runReadLocked(() async {
        final newEntries = await (filter != null
            ? firebaseStore.query(filter)
            : firebaseStore.all());
        await _reset(newEntries);
      });

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

  Future<T?> fetch(String key) => _lock.runReadLocked(() async {
        final value = await firebaseStore.read(key);
        if (value != null) {
          await storage.writeEntry(key, value);
        } else {
          await storage.deleteEntry(key);
        }
        return value;
      });

  Future<String> create(T value) => _lock.runWriteLocked(() async {
        final key = await firebaseStore.create(value);
        await storage.writeEntry(key, value);
        return key;
      });

  Future<void> store(String key, T value) => _lock.runWriteLocked(() async {
        await firebaseStore.write(key, value, silent: true);
        await storage.writeEntry(key, value);
      });

  Future<T?> patch(String key, Map<String, dynamic> updateFields) =>
      _lock.runWriteLocked(
        () async {
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
        },
      );

  Future<void> remove(String key) => _lock.runWriteLocked(() async {
        await firebaseStore.delete(key);
        await storage.deleteEntry(key);
      });

  Future<StoreTransaction<T>> transaction(String key) async {
    await _lock.acquireWrite();
    try {
      return ReadOnlyStoreTransaction(
        storage,
        await firebaseStore.transaction(key),
        _lock,
      );
    } catch (e) {
      _lock.release();
      rethrow;
    }
  }

  @protected
  FutureOr<bool> checkOnline() => true;

  Future<void> _handleStreamEvent(StoreEvent<T> event) async =>
      _lock.runReadLocked(
        () => event.when<FutureOr<void>>(
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
            throw UnimplementedError(
                'invalidPath has not been implemented yet');
          },
        ),
      );

  Future<void> _reset(Map<String, T> entries) async {
    switch (reloadStrategy) {
      case ReloadStrategy.clear:
        await storage.clear();
        for (final entry in entries.entries) {
          await storage.writeEntry(entry.key, entry.value);
        }
        break;
      case ReloadStrategy.compareKey:
        final oldKeys = (await storage.keys()).toSet();
        final deletedKeys = oldKeys.difference(entries.keys.toSet());
        for (final entry in entries.entries) {
          await storage.writeEntry(entry.key, entry.value);
        }
        for (final key in deletedKeys) {
          await storage.deleteEntry(key);
        }
        break;
      case ReloadStrategy.compareValue:
        final oldKeys = (await storage.keys()).toSet();
        final deletedKeys = oldKeys.difference(entries.keys.toSet());
        final filteredEntries = await _filterByValue(entries);
        for (final entry in filteredEntries.entries) {
          await storage.writeEntry(entry.key, entry.value);
        }
        for (final key in deletedKeys) {
          await storage.deleteEntry(key);
        }
        break;
    }
  }

  FutureOr<Map<String, T>> _filterByValue(Map<String, T> entries) async {
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
