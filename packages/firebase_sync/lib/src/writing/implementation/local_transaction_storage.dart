import 'dart:async';

import 'package:meta/meta.dart';

import '../../../firebase_sync.dart';
import '../../utils/future_or_x.dart';

typedef _TransactionFn<T extends Object, TR> = FutureOr<TR> Function(
  _LocalTransactionStorageTransaction<T> transaction,
);

@internal
abstract class IConflictResolver<T extends Object> {
  const IConflictResolver._();

  FutureOr<WriteStorageEntry<T>> resolve(
    String key, {
    required WriteStorageEntry<T> local,
    required WriteStorageEntry<T> remote,
  });
}

@internal
class LocalTransactionStorage<T extends Object> {
  final Storage<WriteStorageEntry<T>> rawStorage;
  final IConflictResolver<T> conflictResolver;

  const LocalTransactionStorage({
    required this.rawStorage,
    required this.conflictResolver,
  });

  WriteStorageEntry<T> get nullEntry => const WriteStorageEntry(value: null);

  FutureOr<WriteStorageEntry<T>> get(String key) =>
      rawStorage.readEntry(key).then((entry) => entry ?? nullEntry);

  FutureOr<void> removeDeletedKeys(Iterable<String> allKeys) =>
      _transaction((transaction) => transaction.removeDeletedKeys(allKeys));

  FutureOr<bool> updateFromRemote(
    String key,
    WriteStorageEntry<T> remoteEntry,
  ) =>
      _transaction(
        (transaction) => transaction.updateFromRemote(key, remoteEntry),
      );

  FutureOr<bool> completeUpload({
    required String key,
    required WriteStorageEntry<T> remoteEntry,
    required int knownLocalModifications,
  }) =>
      _transaction(
        (transaction) => transaction.completeUpload(
          key: key,
          remoteEntry: remoteEntry,
          knownLocalModifications: knownLocalModifications,
        ),
      );

  FutureOr<TR> _transaction<TR>(_TransactionFn<T, TR> transactionCallback) =>
      rawStorage.transaction(
        (transaction) => transactionCallback(
          _LocalTransactionStorageTransaction(
            storage: transaction,
            conflictResolver: conflictResolver,
          ),
        ),
      );
}

class _LocalTransactionStorageTransaction<T extends Object>
    extends LocalTransactionStorage<T> {
  _LocalTransactionStorageTransaction({
    required Storage<WriteStorageEntry<T>> storage,
    required IConflictResolver<T> conflictResolver,
  }) : super(
          rawStorage: storage,
          conflictResolver: conflictResolver,
        );

  @override
  FutureOr<void> removeDeletedKeys(Iterable<String> allKeys) => rawStorage
      .keys()
      .then((localKeys) => localKeys.toSet().difference(allKeys.toSet()))
      .forEach(_performDelete);

  @override
  FutureOr<bool> updateFromRemote(
    String key,
    WriteStorageEntry<T> remoteEntry,
  ) =>
      get(key).then((localEntry) {
        if (localEntry.eTag == remoteEntry.eTag) {
          return true;
        } else {
          return _performLocalUpdate(
            key,
            localEntry: localEntry,
            remoteEntry: remoteEntry,
          );
        }
      });

  @override
  FutureOr<bool> completeUpload({
    required String key,
    required WriteStorageEntry<T> remoteEntry,
    required int knownLocalModifications,
  }) =>
      get(key).then((localEntry) {
        if (localEntry.localModifications != knownLocalModifications) {
          return _performLocalUpdate(
            key,
            localEntry: localEntry,
            remoteEntry: localEntry.copyWith(eTag: remoteEntry.eTag),
          );
        } else {
          return _performLocalUpdate(
            key,
            localEntry: localEntry,
            remoteEntry: remoteEntry,
          );
        }
      });

  FutureOr<bool> _performDelete(String key) => get(key).then(
        (localEntry) => _performLocalUpdate(
          key,
          localEntry: localEntry,
          remoteEntry: nullEntry,
        ),
      );

  FutureOr<bool> _performLocalUpdate(
    String key, {
    required WriteStorageEntry<T> localEntry,
    required WriteStorageEntry<T> remoteEntry,
  }) =>
      localEntry.isModified
          ? conflictResolver
              .resolve(
                key,
                local: localEntry,
                remote: remoteEntry,
              )
              .then((resolvedEntry) => _storeLocal(key, resolvedEntry))
              .then((_) => false)
          : _storeLocal(key, remoteEntry).then((_) => true);

  FutureOr<void> _storeLocal(String key, WriteStorageEntry<T> entry) =>
      !entry.isModified && entry.value == null
          ? rawStorage.deleteEntry(key)
          : rawStorage.writeEntry(key, entry);
}
