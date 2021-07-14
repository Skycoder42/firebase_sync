import '../core/store.dart';
import 'sync_job.dart';

class UploadJob<T extends Object> extends SyncJob {
  final SyncStore<T> store;
  final String key;

  UploadJob({
    required this.store,
    required this.key,
  });

  @override
  Future<void> execute() {
    // TODO: implement execute
    throw UnimplementedError();
  }
}
