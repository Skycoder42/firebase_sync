import 'dart:async';

import 'sync_job.dart';

abstract class StreamCancallationToken {
  const StreamCancallationToken._();

  Future<void> cancel();
}

abstract class JobScheduler {
  const JobScheduler._();

  Future<SyncJobResult> addJob(SyncJob job);

  Future<Iterable<SyncJobResult>> addJobs(List<SyncJob> jobs);

  StreamCancallationToken addJobStream(Stream<SyncJob> jobStream);
}
