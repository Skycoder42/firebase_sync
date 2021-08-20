import 'package:firebase_sync/src/core/sync/sync_controller.dart';
import 'package:firebase_sync/src/core/sync/sync_mode.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_data.dart';

class MockSyncController extends Mock implements SyncController {}

void main() {
  group('SyncControllerX', () {
    final mockSyncController = MockSyncController();

    setUp(() {
      reset(mockSyncController);
    });

    testData<Tuple2<SyncMode, bool>>(
      'isDownsyncActive returns correct value',
      const [
        Tuple2(SyncMode.none, false),
        Tuple2(SyncMode.download, true),
        Tuple2(SyncMode.upload, false),
        Tuple2(SyncMode.sync, true),
      ],
      (fixture) {
        when(() => mockSyncController.syncMode).thenReturn(fixture.item1);
        expect(mockSyncController.isDownsyncActive, fixture.item2);
      },
    );

    testData<Tuple2<SyncMode, bool>>(
      'isUpssyncActive returns correct value',
      const [
        Tuple2(SyncMode.none, false),
        Tuple2(SyncMode.download, false),
        Tuple2(SyncMode.upload, true),
        Tuple2(SyncMode.sync, true),
      ],
      (fixture) {
        when(() => mockSyncController.syncMode).thenReturn(fixture.item1);
        expect(mockSyncController.isUpssyncActive, fixture.item2);
      },
    );
  });
}
