import 'dart:async';

import 'sync_job.dart';

abstract class StreamCancallationToken {
  const StreamCancallationToken._(); // coverage:ignore-line

  Future<void> cancel();
}

abstract class JobScheduler {
  const JobScheduler._(); // coverage:ignore-line

  Future<SyncJobResult> addJob(SyncJob job);

  Future<Iterable<SyncJobResult>> addJobs(List<SyncJob> jobs);

  StreamCancallationToken addJobStream(
    Stream<SyncJob> jobStream, [
    String? source,
  ]);

  Future<void> purgeJobs(String storeName);
}
