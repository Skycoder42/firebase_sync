import 'package:firebase_sync/src/sync/sync_job.dart';

abstract class JobScheduler {
  const JobScheduler._();

  Future<bool> addJob(SyncJob job);
  void addJobStream(Stream<SyncJob> jobStream);
}
