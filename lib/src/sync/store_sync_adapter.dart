import 'dart:web_gl';

import '../core/store.dart';
import '../core/sync_object.dart';
import 'sync_job.dart';
import 'upload_job.dart';

extension SyncStoreUploadExtension<T extends Object> on SyncStore<T> {
  Future<Iterable<SyncJob>> getUploadable() async {
    final entries = await listEntries();
    return entries.entries
        .where((entry) => entry.value.changeState == ChangeState.modified)
        .map((entry) => UploadJob(store: this, key: entry.key));
  }

  Stream<SyncJob> streamUploadable() => watch()
      .where(
        (event) =>
            (event.value?.changeState ?? ChangeState.unchanged) ==
            ChangeState.modified,
      )
      .map((event) => UploadJob(store: this, key: event.key));
}
