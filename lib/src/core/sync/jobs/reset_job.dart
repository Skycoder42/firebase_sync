import 'dart:async';

import '../../crypto/cipher_message.dart';
import '../executable_sync_job.dart';
import '../expandable_sync_job.dart';
import '../sync_node.dart';
import 'reset_local_mixin.dart';

class ResetJob<T extends Object> extends ExpandableSyncJob
    with ResetLocalMixin<T> {
  @override
  final SyncNode<T> syncNode;
  final Map<String, CipherMessage> data;

  ResetJob({
    required this.syncNode,
    required this.data,
  });

  @override
  Stream<ExecutableSyncJob> expandImpl() => Stream.fromIterable(
        generateJobs(
          data: data,
          conflictsTriggerUpload: false,
        ),
      );
}
