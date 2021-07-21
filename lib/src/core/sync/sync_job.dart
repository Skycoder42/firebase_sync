import 'dart:async';

import 'package:meta/meta.dart';

enum SyncJobResult {
  success,
  noop,
  failure,
}

abstract class SyncJob {
  final _completer = Completer<SyncJobResult>();

  @nonVirtual
  Future<SyncJobResult> get result => _completer.future;

  String get storeName;
  String get key;

  @nonVirtual
  Future<void> call() => Future(() async {
        try {
          final modified = await execute();
          _completer.complete(
            modified ? SyncJobResult.success : SyncJobResult.noop,
          );
        } catch (e) {
          _completer.complete(SyncJobResult.failure);
          rethrow;
        }
      });

  @nonVirtual
  bool checkConflict(SyncJob other) =>
      storeName == other.storeName && key == other.key;

  @protected
  Future<bool> execute();
}
