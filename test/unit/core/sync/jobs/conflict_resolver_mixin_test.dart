// ignore_for_file: invalid_use_of_protected_member
import 'dart:typed_data';

import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:firebase_sync/src/core/store/update_action.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/jobs/conflict_resolver_mixin.dart';
import 'package:firebase_sync/src/core/sync/sync_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockConflictResolver extends Mock implements ConflictResolver<int> {}

class Sut extends SyncJob with ConflictResolverMixin<int> {
  @override
  final SyncNode<int> syncNode;

  Sut(this.syncNode);
}

void main() {
  group('ConflictResolverMixin', () {
    final mockSyncNode = MockSyncNode();
    final mockConflictResolver = MockConflictResolver();

    late Sut sut;

    setUp(() {
      reset(mockSyncNode);
      reset(mockConflictResolver);

      when(() => mockSyncNode.conflictResolver)
          .thenReturn(mockConflictResolver);
      when(
        () => mockConflictResolver.resolve(
          any(),
          local: any(named: 'local'),
          remote: any(named: 'remote'),
        ),
      ).thenReturn(const ConflictResolution.delete());

      sut = Sut(mockSyncNode);
    });

    group('resolveConflict', () {
      const key = 'key';

      test('asserts if local data has not been modified', () {
        expect(
          () => sut.resolveConflict(
            key: key,
            localData: SyncObject.remote(10, SyncObject.noRemoteDataTag),
            remoteData: 20,
            remoteTag: Uint8List(SyncObject.remoteTagMin),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('asserts if remote data is the same', () {
        expect(
          () => sut.resolveConflict(
            key: key,
            localData: SyncObject.local(10),
            remoteData: 20,
            remoteTag: SyncObject.noRemoteDataTag,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('calls resolve with correct data', () {
        const localValue = 10;
        const remoteValue = 20;

        sut.resolveConflict(
          key: key,
          localData: SyncObject.local(localValue),
          remoteData: remoteValue,
          remoteTag: Uint8List(SyncObject.remoteTagMin),
        );

        verify(
          () => mockConflictResolver.resolve(
            key,
            local: localValue,
            remote: remoteValue,
          ),
        );
      });

      group('returns', () {
        const remoteData = 10;
        final remoteTag = Uint8List.fromList(
          List.generate(
            SyncObject.remoteTagMin,
            (index) => index,
          ),
        );
        final localData = SyncObject(
          value: 20,
          changeState: 10,
          remoteTag: Uint8List.fromList(
            List.generate(
              SyncObject.remoteTagMin,
              (index) => 255 - index,
            ),
          ),
        );

        UpdateAction<SyncObject<int>> act(
          ConflictResolution<int> resolution, {
          bool deleted = false,
        }) {
          when(
            () => mockConflictResolver.resolve(
              any(),
              local: any(named: 'local'),
              remote: any(named: 'remote'),
            ),
          ).thenReturn(resolution);

          return sut.resolveConflict(
            key: key,
            localData: localData,
            remoteData: deleted ? null : remoteData,
            remoteTag: deleted ? SyncObject.noRemoteDataTag : remoteTag,
          );
        }

        test('local data with remote tag on ConflictResolution.local', () {
          final result = act(const ConflictResolution.local());

          result.maybeWhen(
            orElse: () => fail('Expected UpdateAction.update, but was $result'),
            update: (value) {
              expect(value.value, localData.value);
              expect(value.changeState, localData.changeState);
              expect(value.remoteTag, remoteTag);
            },
          );
        });

        test('remote data with remote tag on ConflictResolution.remote', () {
          final result = act(const ConflictResolution.remote());

          result.maybeWhen(
            orElse: () => fail('Expected UpdateAction.update, but was $result'),
            update: (value) {
              expect(value.value, remoteData);
              expect(value.changeState, 0);
              expect(value.remoteTag, remoteTag);
            },
          );
        });

        test('delete on ConflictResolution.remote without data', () {
          final result = act(const ConflictResolution.remote(), deleted: true);

          result.maybeWhen(
            orElse: () => fail('Expected UpdateAction.delete, but was $result'),
            delete: () {},
          );
        });

        test('update delete with remote tag on ConflictResolution.delete', () {
          final result = act(const ConflictResolution.delete());

          result.maybeWhen(
            orElse: () => fail('Expected UpdateAction.update, but was $result'),
            update: (value) {
              expect(value.value, isNull);
              expect(value.changeState, localData.changeState + 1);
              expect(value.remoteTag, remoteTag);
            },
          );
        });

        test('delete on ConflictResolution.delete without data', () {
          final result = act(const ConflictResolution.delete(), deleted: true);

          result.maybeWhen(
            orElse: () => fail('Expected UpdateAction.delete, but was $result'),
            delete: () {},
          );
        });

        test('updated data on ConflictResolution.update', () {
          const updatedData = 30;
          final result = act(const ConflictResolution.update(updatedData));

          result.maybeWhen(
            orElse: () => fail('Expected UpdateAction.update, but was $result'),
            update: (value) {
              expect(value.value, updatedData);
              expect(value.changeState, localData.changeState + 1);
              expect(value.remoteTag, remoteTag);
            },
          );
        });
      });
    });
  });
}
