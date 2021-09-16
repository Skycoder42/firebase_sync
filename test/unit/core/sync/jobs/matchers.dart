import 'package:firebase_sync/src/core/sync/jobs/download_delete_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_update_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:test/test.dart';

Matcher isDeleteJob<T extends Object>(
  String key,
  SyncNode<T> syncNode,
  dynamic conflictsTriggerUploadMatcher,
) =>
    isA<DownloadDeleteJob<T>>()
        .having((j) => j.key, 'key', key)
        .having((j) => j.syncNode, 'syncNode', same(syncNode))
        .having(
          (j) => j.conflictsTriggerUpload,
          'conflictsTriggerUpload',
          conflictsTriggerUploadMatcher ?? isTrue,
        );

Matcher isUpdateJob<T extends Object>(
  String key,
  dynamic dataMatcher,
  SyncNode<T> syncNode,
  dynamic conflictsTriggerUploadMatcher,
) =>
    isA<DownloadUpdateJob<T>>()
        .having((j) => j.key, 'key', key)
        .having((j) => j.remoteCipher, 'remoteCipher', dataMatcher)
        .having((j) => j.syncNode, 'syncNode', same(syncNode))
        .having(
          (j) => j.conflictsTriggerUpload,
          'conflictsTriggerUpload',
          conflictsTriggerUploadMatcher ?? isTrue,
        );
