import 'sync_job.dart';

abstract class JobScheduler {
  const JobScheduler._();

  Future<SyncJobResult> addJob(SyncJob job);

  Future<Iterable<SyncJobResult>> addJobs(List<SyncJob> jobs);

  void addJobStream(Stream<SyncJob> jobStream);
}
