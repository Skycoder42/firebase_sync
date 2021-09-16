// ignore_for_file: invalid_use_of_protected_member
import 'dart:typed_data';

import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/sync/jobs/upload_all_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/upload_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../test_data.dart';
import 'download_all_job_test.dart';

class MockSyncJob extends Mock implements SyncNode<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

void main() {
  group('UploadAllJob', () {
    final mockSyncNode = MockSyncNode();
    final mockSyncObjectStore = MockSyncObjectStore();

    Matcher isUploadJob(dynamic key, dynamic multipass) => isA<UploadJob<int>>()
        .having(
          (j) => j.syncNode,
          'syncNode',
          same(mockSyncNode),
        )
        .having(
          (j) => j.key,
          'key',
          key,
        )
        .having(
          (j) => j.multipass,
          'multipass',
          multipass,
        );

    setUp(() {
      reset(mockSyncNode);
      reset(mockSyncObjectStore);

      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);
    });

    group('expandImpl', () {
      testData<bool>(
        'generates uploadJobs for all modified entries',
        const [false, true],
        (fixture) {
          when(() => mockSyncObjectStore.listEntries()).thenAnswer(
            (i) async => {
              'a': SyncObject.deleted(),
              'b': SyncObject.local(42),
              'c': SyncObject.remote(10, Uint8List(SyncObject.remoteTagMin)),
              'd': SyncObject(
                value: null,
                changeState: 5,
                remoteTag: SyncObject.noRemoteDataTag,
              ),
            },
          );

          final sut = UploadAllJob(
            syncNode: mockSyncNode,
            multipass: fixture,
          );
          final stream = sut.expandImpl();

          expect(
            stream,
            emitsInOrder(<dynamic>[
              isUploadJob('b', fixture),
              isUploadJob('d', fixture),
            ]),
          );
        },
        fixtureToString: (fixture) => '[conflictsTriggerUpload: $fixture]',
      );
    });
  });
}
