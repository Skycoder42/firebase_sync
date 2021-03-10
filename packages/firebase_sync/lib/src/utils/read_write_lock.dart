import 'dart:async';

import 'package:meta/meta.dart';

class _LockRequest {
  final bool isWriteLock;
  final Completer<void> completer;

  _LockRequest({required this.isWriteLock}) : completer = Completer<void>();
}

@internal
class ReadWriteLock {
  final _pendingLocks = <_LockRequest>[];
  var _lockState = 0;

  bool get isReadLocked => _lockState > 0;

  bool get isWriteLocked => _lockState < 0;

  bool get isLocked => _lockState != 0;

  bool get hasPendingLocks => _pendingLocks.isNotEmpty;

  FutureOr<void> acquireRead() => _acquire(false);

  FutureOr<void> acquireWrite() => _acquire(true);

  void release() {
    assert(isLocked, 'Invalid lock state: $_lockState');

    // release the current lock
    if (isWriteLocked) {
      _lockState = 0;
    } else {
      --_lockState;
    }

    // run the next if no locks left
    while (_canLockNext()) {
      final nextLock = _pendingLocks.removeAt(0);
      _updateLockState(nextLock.isWriteLock);
      nextLock.completer.complete();
    }
  }

  Future<T> runReadLocked<T>(FutureOr<T> Function() call) async {
    await acquireRead();
    try {
      return await call();
    } finally {
      release();
    }
  }

  Future<T> runWriteLocked<T>(FutureOr<T> Function() call) async {
    await acquireWrite();
    try {
      return await call();
    } finally {
      release();
    }
  }

  bool tryPromoteLock() {
    assert(isReadLocked, 'Can only promote read locks');

    // special handling: this read lock is the only one
    // pending write/reads are ignored
    if (_lockState == 1) {
      _lockState = -1;
      return true;
    }

    return false;
  }

  FutureOr<void> relockAsWrite() {
    if (tryPromoteLock()) {
      return null;
    }

    final newLock = acquireWrite();
    release();
    return newLock;
  }

  FutureOr<void> _acquire(bool isWriteLock) {
    // not locked -> just lock
    if (!isLocked) {
      _updateLockState(isWriteLock);
      return null;
    }

    // trying to get a write lock and locked -> queue it
    if (isWriteLock) {
      return _createPendingLock(true);
    }

    // trying to get a read lock, but
    //   - currently write locked or
    //   - other locks are pending
    // -> queue it
    if (isWriteLocked || hasPendingLocks) {
      return _createPendingLock(false);
    }

    // only read locks -> increment lock and return
    assert(isReadLocked);
    _updateLockState(false);
    return null;
  }

  void _updateLockState(bool isWriteLock) {
    if (isWriteLock) {
      assert(
        !isLocked,
        'Invalid state: cannot writelock with other active locks ($_lockState)',
      );
      _lockState = -1;
    } else {
      assert(
        !isWriteLocked,
        'Invalid state: cannot read lock with active write lock',
      );
      ++_lockState;
    }
  }

  Future<void> _createPendingLock(bool isWriteLock) {
    final request = _LockRequest(isWriteLock: isWriteLock);
    _pendingLocks.add(request);
    return request.completer.future;
  }

  bool _canLockNext() {
    // No more locks available -> can't lock
    if (_pendingLocks.isEmpty) {
      return false;
    }

    // not locked yet -> can lock
    if (!isLocked) {
      return true;
    }

    // current and next are read locks -> can lock
    if (isReadLocked && !_pendingLocks.first.isWriteLock) {
      return true;
    }

    // all other cases -> can't lock
    return false;
  }
}
