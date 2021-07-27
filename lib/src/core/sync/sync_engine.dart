import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'job_scheduler.dart';
import 'sync_job.dart';

class SyncEngine implements JobScheduler {
  static const defaultParallelJobs = 5;

  int _parallelJobs;
  bool _paused = false;

  Zone? _syncZone;
  final _jobQueue = LinkedList<_JobListEntry>();
  final _activeJobs = <SyncJob>[];
  final _jobStreamSubscriptions = <StreamSubscription<SyncJob>>[];

  Future<void>? _stopFuture;

  SyncEngine({
    int parallelJobs = defaultParallelJobs,
  }) : _parallelJobs = parallelJobs;

  int get parallelJobs => _parallelJobs;

  set parallelJobs(int parallelJobs) {
    if (parallelJobs > _parallelJobs) {
      _parallelJobs = parallelJobs;
      _run();
    } else {
      _parallelJobs = parallelJobs;
    }
  }

  bool get running => _syncZone != null;

  void start() {
    _stopFuture = null;

    _syncZone ??= Zone.current.fork(
      specification: ZoneSpecification(
        handleUncaughtError: _handleZoneError,
      ),
    );

    _run();
  }

  Future<void> stop({bool clearPendingJobs = true}) async {
    _syncZone = null;

    if (clearPendingJobs) {
      _jobQueue.clear();
    }

    _stopFuture ??= Future.wait(
      _jobStreamSubscriptions
          .map(
            (sub) => sub.cancel(),
          )
          .followedBy(
            _activeJobs.map((j) => j.result),
          ),
    );

    await _stopFuture;
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
    _jobQueue.add(_JobListEntry(job));
    _run();
    return job.result;
  }

  @override
  @internal
  Future<Iterable<SyncJobResult>> addJobs(List<SyncJob> jobs) {
    _jobQueue.addAll(jobs.map((job) => _JobListEntry(job)));
    _run();
    return Future.wait(jobs.map((job) => job.result));
  }

  @override
  @internal
  StreamCancallationToken addJobStream(Stream<SyncJob> jobStream) {
    final subscription = jobStream.listen(
      addJob,
      onError: _syncZone!.handleUncaughtError,
      cancelOnError: false,
    );
    // TODO test if this works with cancelling
    subscription.onDone(() => _jobStreamSubscriptions.remove(subscription));
    if (_paused) {
      subscription.pause();
    }
    _jobStreamSubscriptions.add(subscription);

    return _EngineStreamCancallationToken(this, subscription);
  }

  void _run() {
    if (_syncZone == null) {
      return;
    }

    _syncZone!.parent!.runGuarded(() {
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
    assert(_syncZone != null);

    try {
      _activeJobs.add(job);
      _syncZone!.run(() {
        Timer.run(() {
          job().whenComplete(() => _completeJob(job));
        });
      });
    } catch (e) {
      _activeJobs.remove(job);
      _jobQueue.add(_JobListEntry(job));
      rethrow;
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
      // TODO clean
      // ignore: avoid_print
      print('$error\n$stackTrace');
    } catch (e, s) {
      if (identical(e, error)) {
        parent.handleUncaughtError(zone, error, stackTrace);
      } else {
        parent.handleUncaughtError(zone, e, s);
      }
    }
  }
}

class _EngineStreamCancallationToken implements StreamCancallationToken {
  final SyncEngine _engine;
  final StreamSubscription _streamSubscription;

  _EngineStreamCancallationToken(this._engine, this._streamSubscription);

  @override
  Future<void> cancel() {
    if (_engine._jobStreamSubscriptions.remove(_streamSubscription)) {
      return _streamSubscription.cancel();
    } else {
      return Future.value();
    }
  }
}

class _JobListEntry extends LinkedListEntry<_JobListEntry> {
  final SyncJob job;

  _JobListEntry(this.job);
}
