import 'dart:async';

import 'sync_error.dart';
import 'sync_error_transformer.dart';
import 'sync_job.dart';

class SyncJobExecutor {
  final _streamController = StreamController<SyncJob>();
  // ignore: close_sinks
  final _errorStreamController = StreamController<SyncError>.broadcast();

  SyncJobExecutor() {
    _streamController.stream
        .asyncExpand(_expandAndExecute)
        .map(_checkReschedule)
        .mapSyncErrors()
        .pipe(_errorStreamController);
    // TODO as broadcast maybe? would require subscrption to the error stream
  }

  Future<void> close() async {
    await _streamController.close();
  }

  Future<SyncJobResult> add(SyncJob syncJob) {
    _streamController.add(syncJob);
    return syncJob.result;
  }

  Stream<SyncJobResult> addAll(Iterable<SyncJob> syncJobs) =>
      Stream.fromFutures(syncJobs.map(add));

  StreamSubscription<void> addStream(
    Stream<SyncJob> syncJobStream,
  ) {
    final subscription = syncJobStream.listen(
      _streamController.add,
      onError: _streamController.addError,
      cancelOnError: false,
    );

    // TODO test if this works
    _streamController.done.then((dynamic _) => subscription.cancel());

    return subscription;
  }

  Stream<SyncJob?> _expandAndExecute(SyncJob syncJob) => syncJob
      .expand()
      .asyncMap((executableSyncJob) => executableSyncJob.execute());

  void _checkReschedule(SyncJob? syncJob) {
    if (syncJob != null) {
      _streamController.add(syncJob);
    }
  }
}
