import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../../storage/storage.dart';
import '../read_store_remote.dart';
import 'read_only_store_transaction.dart';

@internal
mixin RemoteMixin<T extends Object> implements ReadStoreRemote<T> {
  ReloadStrategy get reloadStrategy;

  Storage<T> get storage;

  FirebaseStore<T> get firebaseStore;

  void onInvalidPath(String path);

  @override
  Future<void> reload([Filter? filter]) async {
    final newEntries = await (filter != null
        ? firebaseStore.query(filter)
        : firebaseStore.all());
    await _reset(newEntries);
  }

  @override
  Future<StreamSubscription<void>> sync({
    Filter? filter,
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) async {
    final stream = await (filter != null
        ? firebaseStore.streamQuery(filter)
        : firebaseStore.streamAll());
    return stream.asyncMap(_handleStreamEvent).listen(
          onUpdate != null ? (_) => onUpdate() : null,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }

  @override
  StreamSubscription<void> syncRenewed({
    FutureOr<Filter> Function()? onRenewFilter,
    void Function()? onUpdate,
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
            onUpdate != null ? (_) => onUpdate() : null,
            onError: onError,
            onDone: onDone,
            cancelOnError: cancelOnError,
          );

  @override
  Future<T?> fetch(String key) async {
    final value = await firebaseStore.read(key);
    if (value != null) {
      await storage.writeEntry(key, value);
    } else {
      await storage.deleteEntry(key);
    }
    return value;
  }

  @override
  Future<String> create(T value) async {
    final key = await firebaseStore.create(value);
    await storage.writeEntry(key, value);
    return key;
  }

  @override
  Future<void> store(String key, T value) async {
    await firebaseStore.write(key, value, silent: true);
    await storage.writeEntry(key, value);
  }

  @override
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

  @override
  Future<void> remove(String key) async {
    await firebaseStore.delete(key);
    await storage.deleteEntry(key);
  }

  @override
  Future<void> destroy(String key) async {
    await firebaseStore.destroy();
    await storage.destroy();
  }

  @override
  Future<FirebaseTransaction<T>> transaction(String key) async {
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
        reset: _reset,
        put: storage.writeEntry,
        delete: storage.deleteEntry,
        patch: (key, patchSet) async {
          final currentValue = await storage.readEntry(key);
          if (currentValue != null) {
            await storage.writeEntry(key, patchSet.apply(currentValue));
          }
        },
        // ignore: void_checks
        invalidPath: onInvalidPath,
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
