import 'dart:async';

import 'package:meta/meta.dart';

abstract class SyncJob {
  final _completer = Completer<bool>();

  @nonVirtual
  Future<bool> get result => _completer.future;

  @nonVirtual
  Future<void> call() async {
    try {
      await execute();
      _completer.complete(true);
    } catch (e) {
      _completer.complete(false);
      rethrow;
    }
  }

  @protected
  Future<void> execute();
}
