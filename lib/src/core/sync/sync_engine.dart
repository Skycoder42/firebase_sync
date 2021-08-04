import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'job_scheduler.dart';
import 'sync_error.dart';
import 'sync_job.dart';

class SyncEngine implements JobScheduler {
  static const defaultParallelJobs = 5;

  int _parallelJobs;
  bool _paused = false;

  final _errorStreamController = StreamController<SyncError>.broadcast();

  late Zone _syncZone;
  final _jobQueue = LinkedList<_JobListEntry>();
  final _activeJobs = <SyncJob>[];
  final _jobStreamSubscriptions = <StreamSubscription<SyncJob>>[];

  Future<void>? _stopFuture;

  SyncEngine({
    int parallelJobs = defaultParallelJobs,
  }) : _parallelJobs = parallelJobs {
    _syncZone = Zone.current.fork(
      specification: ZoneSpecification(
        handleUncaughtError: _handleZoneError,
      ),
    );
  }

  Stream<SyncError> get syncErrors => _errorStreamController.stream;

  int get parallelJobs => _parallelJobs;

  set parallelJobs(int parallelJobs) {
    if (parallelJobs > _parallelJobs) {
      _parallelJobs = parallelJobs;
      _run();
    } else {
      _parallelJobs = parallelJobs;
    }
  }

  Future<void> dispose() {
    if (_stopFuture != null) {
      return _stopFuture!;
    }

    for (final entry in _jobQueue) {
      entry.job.abort();
    }

    _stopFuture ??= Future.wait(
      _jobStreamSubscriptions
          .map((sub) => sub.cancel())
          .followedBy(_activeJobs.map((j) => j.result)),
    ).whenComplete(
      () => _errorStreamController.close(),
    );

    return _stopFuture!;
  }

  bool get paused => _paused;
  set paused(bool paused) {
    if (paused == _paused) {
      return;
    }

    _paused = paused;
    if (_paused) {
      for (final sub in _jobStreamSubscriptions) {
        sub.pause();
      }
    } else {
      for (final sub in _jobStreamSubscriptions) {
        sub.resume();
      }
      _run();
    }
  }

  @override
  @internal
  Future<SyncJobResult> addJob(SyncJob job) {
    _assertNotDisposed();

    _jobQueue.add(_JobListEntry(job));
    _run();
    return job.result;
  }

  @override
  @internal
  Future<Iterable<SyncJobResult>> addJobs(Iterable<SyncJob> jobs) {
    _assertNotDisposed();

    final result = Future.wait(jobs.map((job) {
      _jobQueue.add(_JobListEntry(job));
      return job.result;
    }));
    _run();
    return result;
  }

  @override
  @internal
  StreamCancallationToken addJobStream(Stream<SyncJob> jobStream) {
    _assertNotDisposed();

    final subscription = jobStream.listen(
      addJob,
      onError: (Object e, StackTrace? s) => _errorStreamController.add(
        SyncError.stream(
          error: e,
          stackTrace: s,
          stream: jobStream.runtimeType,
        ),
      ),
      cancelOnError: false,
    );
    _jobStreamSubscriptions.add(subscription);
    subscription.onDone(() {
      _jobStreamSubscriptions.remove(subscription);
    });
    if (_paused) {
      subscription.pause();
    }

    return _EngineStreamCancallationToken(
      engine: this,
      streamSubscription: subscription,
    );
  }

  void _run() {
    if (_stopFuture != null) {
      return;
    }

    _syncZone.parent!.runGuarded(() {
      while (!_paused && _activeJobs.length < _parallelJobs) {
        final job = _nextJob();
        if (job == null) {
          break;
        }

        _executeJob(job);
      }
    });
  }

  void _executeJob(SyncJob job) {
    try {
      _activeJobs.add(job);
      _syncZone.run(() {
        Timer.run(() {
          job().whenComplete(() => _completeJob(job)).catchError(
                (Object e, StackTrace? s) => _errorStreamController.add(
                  SyncError.job(
                    error: e,
                    stackTrace: s,
                    storeName: job.storeName,
                    key: job.key,
                  ),
                ),
                test: (e) => e is Exception,
              );
        });
      });
    } catch (e) {
      // coverage:ignore-start
      _activeJobs.remove(job);
      _jobQueue.add(_JobListEntry(job));
      rethrow;
      // coverage:ignore-end
    }
  }

  void _completeJob(SyncJob job) {
    _activeJobs.remove(job);
    _run();
  }

  SyncJob? _nextJob() {
    final nextJob = _jobQueue.cast<_JobListEntry?>().firstWhere(
          (entry) => !_activeJobs.any((job) => entry!.job.checkConflict(job)),
          orElse: () => null,
        );
    if (nextJob == null) {
      return null;
    }

    nextJob.unlink();
    return nextJob.job;
  }

  void _handleZoneError(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Object error,
    StackTrace stackTrace,
  ) {
    try {
      _errorStreamController.add(SyncError.uncaught(error, stackTrace));
    } catch (e, s) {
      // coverage:ignore-start
      if (identical(e, error)) {
        parent.handleUncaughtError(zone, error, stackTrace);
      } else {
        parent.handleUncaughtError(zone, e, s);
      }
      // coverage:ignore-end
    }
  }

  void _assertNotDisposed() {
    if (_stopFuture != null) {
      throw StateError('SyncEngine has already been disposed!');
    }
  }
}

class _EngineStreamCancallationToken implements StreamCancallationToken {
  final SyncEngine engine;
  final StreamSubscription streamSubscription;

  _EngineStreamCancallationToken({
    required this.engine,
    required this.streamSubscription,
  });

  @override
  Future<void> cancel() {
    if (engine._jobStreamSubscriptions.remove(streamSubscription)) {
      return streamSubscription.cancel();
    } else {
      return Future.value();
    }
  }
}

class _JobListEntry extends LinkedListEntry<_JobListEntry> {
  final SyncJob job;

  _JobListEntry(this.job);
}
