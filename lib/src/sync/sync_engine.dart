import 'dart:async';
import 'dart:collection';

import 'sync_job.dart';

class SyncEngine {
  int _parallelJobs = 5;
  bool _paused = false;

  Zone? _syncZone;
  final _jobQueue = Queue<SyncJob>();
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

  Future<bool> addJob(SyncJob job) {
    _jobQueue.add(job);
    _invokeRun();
    return job.result;
  }

  void addJobStream(Stream<SyncJob> jobStream) {
    if (_syncZone == null) {
      throw UnimplementedError();
    }

    _syncZone!.runGuarded(() => _subscribe(jobStream));
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
    while (!_paused &&
        _activeJobs.length < _parallelJobs &&
        _jobQueue.isNotEmpty) {
      final nextJob = _jobQueue.removeFirst();
      nextJob().whenComplete(() {
        _activeJobs.remove(nextJob);
        _enqueueRun();
      });
      _activeJobs.add(nextJob);
    }
  }

  void _subscribe(Stream<SyncJob> jobStream) {
    final subscription = jobStream.listen(
      (job) {
        _jobQueue.add(job);
        _enqueueRun();
      },
      cancelOnError: false,
    );
    if (_paused) {
      subscription.pause();
    }
    // TODO test if this works with cancelling
    subscription.onDone(() => _jobStreamSubscriptions.remove(subscription));
    _jobStreamSubscriptions.add(subscription);
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
