import 'dart:async';

import 'sync_error.dart';
import 'sync_error_transformer.dart';
import 'sync_job.dart';

class SyncJobExecutor {
  final _streamController = StreamController<SyncJobCollection>();
  // ignore: close_sinks
  final _errorStreamController = StreamController<SyncError>.broadcast();

  SyncJobExecutor() {
    _streamController.stream
        .asyncExpand(
          (collection) => collection.expand().asyncMap((job) => job()),
        )
        .map(_checkReschedule)
        .mapSyncErrors()
        .pipe(_errorStreamController);
    // TODO as broadcast maybe? would require subscrption to the error stream
  }

  Future<void> close() async {
    await _streamController.close();
  }

  Stream<SyncJobResult> addCollection(SyncJobCollection syncJobCollection) {
    _streamController.add(syncJobCollection);
    return syncJobCollection.results;
  }

  StreamSubscription<void> addCollectionStream(
    Stream<SyncJobCollection> syncJobCollectionStream,
  ) {
    final subscription = syncJobCollectionStream.listen(
      _streamController.add,
      onError: _streamController.addError,
      cancelOnError: false,
    );

    // TODO test if this works
    _streamController.done.then((dynamic _) => subscription.cancel());

    return subscription;
  }

  Future<SyncJobResult> add(SyncJob syncJob) {
    addCollection(SyncJobCollection.single(syncJob));
    return syncJob.result;
  }

  Stream<SyncJobResult> addAll(Iterable<SyncJob> syncJobs) =>
      Stream.fromFutures(syncJobs.map(add));

  StreamSubscription<void> addStream(Stream<SyncJob> syncJobStream) =>
      addCollectionStream(
        syncJobStream.map(
          (job) => SyncJobCollection.single(job),
        ),
      );

  void _checkReschedule(SyncJob? syncJob) {
    if (syncJob != null) {
      add(syncJob);
    }
  }
}
