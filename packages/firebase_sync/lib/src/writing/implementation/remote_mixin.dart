import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../../storage/local_store_event.dart';
import '../../storage/write_storage_entry.dart';
import '../../utils/future_or_x.dart';
import '../conflict_resolution.dart';
import '../write_store_remote.dart';
import 'local_transaction_storage.dart';

typedef UpdateLocalFn<T extends Object, TR> = FutureOr<TR> Function(
  WriteStorageEntry<T> localEntry,
);

@internal
mixin RemoteMixin<T extends Object>
    implements WriteStoreRemote<T>, IConflictResolver<T> {
  @visibleForOverriding
  LocalTransactionStorage<T> get transactionStorage;

  @visibleForOverriding
  FirebaseStore<T> get firebaseStore;

  @protected
  FutureOr<ConflictResolution<T>> resolveConflict(
    String key,
    T? local,
    T? remote,
  ) =>
      const ConflictResolution.remote();

  @override
  Future<void> download([Filter? filter]) async {
    final eTagReceiver = ETagReceiver();
    final remoteKeys = await (filter != null
        ? firebaseStore.queryKeys(filter)
        : firebaseStore.keys(eTagReceiver: eTagReceiver));
    // TODO use eTag for quick updating?
    await _downloadAll(remoteKeys);
  }

  @override
  Future<void> upload({bool multipass = true}) async {
    bool hasChanges;
    do {
      hasChanges = false;
      for (final key in await transactionStorage.rawStorage.keys()) {
        final entry = await transactionStorage.get(key);
        if (entry.isModified) {
          final uploaded = await _uploadEntry(key, entry);
          hasChanges |= !uploaded;
        }
      }
    } while (multipass && hasChanges);
  }

  @override
  Future<void> reload({Filter? filter, bool multipass = true}) async {
    await download(filter);
    await upload(multipass: multipass);
  }

  @override
  Future<StreamSubscription<void>> syncDownload({
    Filter? filter,
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) async {
    final stream = await (filter != null
        ? firebaseStore.streamQueryKeys(filter)
        : firebaseStore.streamKeys());
    return _transformDownloads(stream).listen(
      onUpdate != null ? (_) => onUpdate() : null,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  StreamSubscription<void> syncDownloadRenewed({
    FutureOr<Filter> Function()? onRenewFilter,
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) =>
      _transformDownloads(AutoRenewStream(() async {
        final filter = await onRenewFilter?.call();
        return filter != null
            ? firebaseStore.streamQueryKeys(filter)
            : firebaseStore.streamKeys();
      })).listen(
        onUpdate != null ? (_) => onUpdate() : null,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  Future<StreamSubscription<void>> syncUpload({
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) async {
    final subscription =
        _transformUploads(transactionStorage.rawStorage.watch()).listen(
      onUpdate != null ? (_) => onUpdate() : null,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    try {
      subscription.pause();
      await upload(multipass: false);
      subscription.resume();
      return subscription;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  @override
  Future<String> create(T value) async {
    final eTagReceiver = ETagReceiver();
    final remoteKey = await firebaseStore.create(
      value,
      eTagReceiver: eTagReceiver,
    );
    await transactionStorage.updateFromRemote(
      remoteKey,
      WriteStorageEntry(
        value: value,
        eTag: eTagReceiver.eTag ?? WriteStoreRemote.invalidETag,
      ),
    );
    return remoteKey;
  }

  @override
  Future<void> destroy() async {
    await firebaseStore.destroy();
    await transactionStorage.rawStorage.destroy();
  }

  @override
  @internal
  FutureOr<WriteStorageEntry<T>> resolve(
    String key, {
    required WriteStorageEntry<T> local,
    required WriteStorageEntry<T> remote,
  }) {
    assert(
      local.isModified,
      'Can only resolve conflicts for modified entries',
    );
    assert(
      !remote.isModified,
      'A remote entry cannot be modified',
    );
    assert(
      local.eTag != remote.eTag,
      'Can only resolve conflicts for diverging entries',
    );

    return resolveConflict(key, local.value, remote.value).then(
      (resolution) => resolution.when(
        local: () => local.copyWith(
          eTag: remote.eTag,
        ),
        remote: () => remote,
        delete: () => local.updateLocal(null, eTag: remote.eTag),
        update: (data) => local.updateLocal(data, eTag: remote.eTag),
      ),
    );
  }

  Future<void> _downloadAll(List<String> remoteKeys) async {
    await transactionStorage.removeDeletedKeys(remoteKeys);
    for (final key in remoteKeys) {
      await _downloadEntry(key);
    }
  }

  Future<void> _downloadEntry(String key) async {
    final eTagReceiver = ETagReceiver();
    final value = await firebaseStore.read(
      key,
      eTagReceiver: eTagReceiver,
    );
    await transactionStorage.updateFromRemote(
      key,
      WriteStorageEntry(
        value: value,
        eTag: eTagReceiver.eTag ?? WriteStoreRemote.invalidETag,
      ),
    );
  }

  FutureOr<void> _deleteFromRemote(String key) =>
      transactionStorage.updateFromRemote(key, transactionStorage.nullEntry);

  Future<bool> _uploadEntry(String key, WriteStorageEntry<T> localEntry) async {
    assert(localEntry.isModified, 'Can only upload modified entries');
    // optimistic sync approach
    try {
      final eTagReceiver = ETagReceiver();
      T? storeValue;
      if (localEntry.value != null) {
        storeValue = await firebaseStore.write(
          key,
          localEntry.value!,
          eTag: localEntry.eTag,
          eTagReceiver: eTagReceiver,
        );
      } else {
        await firebaseStore.delete(
          key,
          eTag: localEntry.eTag,
          eTagReceiver: eTagReceiver,
        );
      }

      return transactionStorage.completeUpload(
        key: key,
        remoteEntry: WriteStorageEntry(
          value: storeValue,
          eTag: eTagReceiver.eTag ?? WriteStoreRemote.invalidETag,
        ),
        knownLocalModifications: localEntry.localModifications,
      );
    } on DbException catch (e) {
      if (e.statusCode == ApiConstants.statusCodeETagMismatch) {
        await _downloadEntry(key);
        return false;
      } else {
        rethrow;
      }
    }
  }

  Stream<void> _transformDownloads(Stream<KeyEvent> stream) => stream.asyncMap(
        (event) => event.when<FutureOr<void>>(
          reset: _downloadAll,
          update: _downloadEntry,
          delete: _deleteFromRemote,
          // ignore: void_checks
          invalidPath: (path) {
            throw UnimplementedError(
              'invalidPath has not been implemented yet',
            );
          },
        ),
      );

  Stream<void> _transformUploads(
    Stream<LocalStoreEvent<WriteStorageEntry<T>>> stream,
  ) =>
      stream.asyncMap(
        (event) => event.when<FutureOr<void>>(
          // ignore: void_checks
          update: (key, entry) {
            if (entry.isModified) {
              return _uploadEntry(key, entry);
            }
          },
          delete: (_) {},
        ),
      );
}
