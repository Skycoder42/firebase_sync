import 'dart:async';
import 'dart:collection';

import 'package:firebase_sync/src/sync/job_scheduler.dart';

import 'sync_job.dart';

class _JobListEntry extends LinkedListEntry<_JobListEntry> {
  final SyncJob job;

  _JobListEntry(this.job);
}

class SyncEngine implements JobScheduler {
  int _parallelJobs = 5;
  bool _paused = false;

  Zone? _syncZone;
  final _jobQueue = LinkedList<_JobListEntry>();
  final _activeJobs = <SyncJob>[];
  final _jobStreamSubscriptions = <StreamSubscription<SyncJob>>[];

  int get parallelJobs => _parallelJobs;

  set parallelJobs(int parallelJobs) {
    if (parallelJobs > _parallelJobs) {
      _parallelJobs = parallelJobs;
      _invokeRun();
    } else {
      _parallelJobs = parallelJobs;
    }
  }

  bool get isRunning => _syncZone != null;

  void start() {
    _syncZone = Zone.current.fork(
      specification: ZoneSpecification(
        handleUncaughtError: _handleZoneError,
      ),
    );
    _invokeRun();
  }

  Future<void> stop({bool clearPendingJobs = true}) async {
    _syncZone = null;

    if (clearPendingJobs) {
      _jobQueue.clear();
    }

    await Future.wait(
      _jobStreamSubscriptions
          .map(
            (sub) => sub.cancel(),
          )
          .followedBy(
            _activeJobs.map((j) => j.result),
          ),
    );
  }

  @override
  Future<bool> addJob(SyncJob job) {
    _jobQueue.add(_JobListEntry(job));
    _invokeRun();
    return job.result;
  }

  @override
  void addJobStream(Stream<SyncJob> jobStream) {
    if (_syncZone == null) {
      throw StateError('Engine must be running to add job streams!');
    }

    final subscription = jobStream.listen(
      _syncZone!.bindUnaryCallbackGuarded((job) {
        _jobQueue.add(_JobListEntry(job));
        _enqueueRun();
      }),
      onError: _syncZone!.handleUncaughtError,
      cancelOnError: false,
    );
    // TODO test if this works with cancelling
    subscription.onDone(() => _jobStreamSubscriptions.remove(subscription));
    if (_paused) {
      subscription.pause();
    }
    _jobStreamSubscriptions.add(subscription);
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
      _invokeRun();
      for (final sub in _jobStreamSubscriptions) {
        sub.resume();
      }
    }
  }

  void _run() {
    while (!_paused && _activeJobs.length < _parallelJobs) {
      final nextJob = _jobQueue.cast<_JobListEntry?>().firstWhere(
            (entry) => !_activeJobs
                .map((j) => j.hashedKey)
                .any((hashedKey) => hashedKey == entry!.job.hashedKey),
            orElse: () => null,
          );
      if (nextJob == null) {
        break;
      }

      nextJob.unlink();
      nextJob.job(this).whenComplete(() {
        _activeJobs.remove(nextJob.job);
        _enqueueRun();
      });
      _activeJobs.add(nextJob.job);
    }
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

  void _invokeRun() {
    assert(Zone.current != _syncZone);
    _syncZone?.runGuarded(_run);
  }

  void _enqueueRun() {
    if (_syncZone == null) {
      return;
    }
    assert(Zone.current == _syncZone);
    _run();
  }
}
