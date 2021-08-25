import '../../store/sync_object.dart';
import '../executable_sync_job.dart';
import '../expandable_sync_job.dart';
import '../sync_node.dart';
import 'upload_job.dart';

class UploadAllJob<T extends Object> extends ExpandableSyncJob {
  final SyncNode<T> syncNode;
  final bool multipass;

  UploadAllJob({
    required this.syncNode,
    required this.multipass,
  });

  @override
  Stream<ExecutableSyncJob> expandImpl() =>
      Stream.fromFuture(Future.value(syncNode.localStore.listEntries()))
          .expand((entries) => entries.entries)
          .where((entry) => entry.value.locallyModified)
          .map(
            (entry) => UploadJob(
              syncNode: syncNode,
              key: entry.key,
              multipass: multipass,
            ),
          );
}
