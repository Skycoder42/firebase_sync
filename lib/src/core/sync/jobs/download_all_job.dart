import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:meta/meta.dart';

import '../executable_sync_job.dart';
import '../expandable_sync_job.dart';
import '../sync_node.dart';
import 'reset_local_mixin.dart';

class DownloadAllJob<T extends Object> extends ExpandableSyncJob
    with ResetLocalMixin<T> {
  @override
  final SyncNode<T> syncNode;
  final Filter? filter;
  final bool conflictsTriggerUpload;

  DownloadAllJob({
    required this.syncNode,
    required this.filter,
    required this.conflictsTriggerUpload,
  });

  @override
  @protected
  Stream<ExecutableSyncJob> expandImpl() => Stream.fromFuture(
        filter != null
            ? syncNode.remoteStore.query(filter!)
            : syncNode.remoteStore.all(),
      ).expand(
        (data) => generateJobs(
          data: data,
          conflictsTriggerUpload: conflictsTriggerUpload,
        ),
      );
}
