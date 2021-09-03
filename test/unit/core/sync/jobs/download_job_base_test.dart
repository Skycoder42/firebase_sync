import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_job_base.dart';
import 'package:firebase_sync/src/core/sync/jobs/upload_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../../test_data.dart';

class FakeSyncNode extends Fake implements SyncNode<int> {}

class Sut extends DownloadJobBase<int> {
  // ignore: avoid_positional_boolean_parameters
  Sut(SyncNode<int> syncNode, bool conflictsTriggerUpload)
      : super(
          syncNode: syncNode,
          conflictsTriggerUpload: conflictsTriggerUpload,
        );

  @override
  Future<ExecutionResult> executeImpl() => throw UnimplementedError();
}

void main() {
  group('DownloadJobBase', () {
    const key = 'key';
    final fakeSyncNode = FakeSyncNode();

    Matcher isUploadJob() => isA<UploadJob<int>>()
        .having((j) => j.key, 'key', key)
        .having((j) => j.syncNode, 'syncNode', same(fakeSyncNode))
        .having((j) => j.multipass, 'multipass', isFalse);

    Matcher isContinued() => isA<ExecutionResult>().having(
          (r) => r.maybeWhen(
            continued: (job) => job,
            orElse: () => null,
          ),
          'continued(job)',
          isUploadJob(),
        );

    // ignore: avoid_positional_boolean_parameters
    Sut createSut(bool conflictsTriggerUpload) =>
        Sut(fakeSyncNode, conflictsTriggerUpload);

    testData<Tuple4<bool, bool, bool, dynamic>>(
      'getResult converts correctly',
      [
        const Tuple4<bool, bool, bool, dynamic>(
          false,
          false,
          false,
          ExecutionResult.noop(),
        ),
        const Tuple4<bool, bool, bool, dynamic>(
          false,
          false,
          true,
          ExecutionResult.modified(),
        ),
        const Tuple4<bool, bool, bool, dynamic>(
          false,
          true,
          false,
          ExecutionResult.noop(),
        ),
        const Tuple4<bool, bool, bool, dynamic>(
          false,
          true,
          true,
          ExecutionResult.modified(),
        ),
        const Tuple4<bool, bool, bool, dynamic>(
          true,
          false,
          false,
          ExecutionResult.noop(),
        ),
        const Tuple4<bool, bool, bool, dynamic>(
          true,
          false,
          true,
          ExecutionResult.modified(),
        ),
        const Tuple4<bool, bool, bool, dynamic>(
          true,
          true,
          false,
          ExecutionResult.noop(),
        ),
        Tuple4<bool, bool, bool, dynamic>(
          true,
          true,
          true,
          isContinued(),
        ),
      ],
      (fixture) {
        final sut = createSut(fixture.item1);

        // ignore: invalid_use_of_protected_member
        final result = sut.getResult(
          key: key,
          hasConflict: fixture.item2,
          modified: fixture.item3,
        );

        expect(result, fixture.item4);
      },
      fixtureToString: (fixture) =>
          '(conflictsTriggerUpload: ${fixture.item1}, '
          'hasConflict: ${fixture.item2}, '
          'modified: ${fixture.item3}) '
          '=> ${fixture.item4}',
    );
  });
}
