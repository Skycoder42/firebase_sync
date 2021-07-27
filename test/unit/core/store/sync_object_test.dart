import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_data.dart';

void main() {
  group('construction', () {
    test('SyncObject uses correct defaults', () {
      const sut = SyncObject<int>(value: null);

      expect(sut.value, isNull);
      expect(sut.changeState, 0);
      expect(sut.eTag, ApiConstants.nullETag);
      expect(sut.plainKey, isNull);
    });

    test('SyncObject asserts if changeState is invalid', () {
      expect(
        () => SyncObject<int>(
          value: null,
          changeState: -10,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('SyncObject.local initializes correctly', () {
      const plainKey = 'key';
      final sut = SyncObject<int>.local(42, plainKey: plainKey);

      expect(sut.value, 42);
      expect(sut.changeState, 1);
      expect(sut.eTag, ApiConstants.nullETag);
      expect(sut.plainKey, plainKey);
    });

    test('SyncObject.remote initializes correctly', () {
      const plainKey = 'key';
      const eTag = 'test';
      final sut = SyncObject<int>.remote(13, eTag, plainKey: plainKey);

      expect(sut.value, 13);
      expect(sut.changeState, 0);
      expect(sut.eTag, eTag);
      expect(sut.plainKey, plainKey);
    });

    test('SyncObject.deleted initializes correctly', () {
      const plainKey = 'deletedKey';
      final sut = SyncObject<int>.deleted(plainKey: plainKey);

      expect(sut.value, isNull);
      expect(sut.changeState, 0);
      expect(sut.eTag, ApiConstants.nullETag);
      expect(sut.plainKey, plainKey);
    });
  });

  group('members', () {
    testData<Tuple2<int, bool>>(
      'locallyModified returns true only if changeState == 0',
      const [
        Tuple2(0, false),
        Tuple2(1, true),
        Tuple2(10, true),
        Tuple2(42, true),
      ],
      (fixture) {
        final sut = SyncObject(value: 0, changeState: fixture.item1);
        expect(sut.locallyModified, fixture.item2);
      },
    );

    group('updateLocal', () {
      const sut = SyncObject(
        value: 10,
        changeState: 5,
        eTag: 'E-TAG',
        plainKey: 'key',
      );

      test('updates value and increments changeState', () {
        final result = sut.updateLocal(20);
        expect(result.value, 20);
        expect(result.changeState, 6);
        expect(result.eTag, sut.eTag);
        expect(result.plainKey, sut.plainKey);
      });

      test('overwrites eTag, if specified', () {
        const newEtag = 'EEE';
        final result = sut.updateLocal(null, eTag: newEtag);
        expect(result.value, isNull);
        expect(result.changeState, 6);
        expect(result.eTag, newEtag);
        expect(result.plainKey, sut.plainKey);
      });
    });

    test('updateRemote', () {
      const sut = SyncObject(
        value: 10,
        changeState: 5,
        eTag: 'E-TAG',
        plainKey: 'key',
      );

      const newEtag = 'uae';
      final result = sut.updateRemote(42, newEtag);
      expect(result.value, 42);
      expect(result.changeState, sut.changeState);
      expect(result.eTag, newEtag);
      expect(result.plainKey, sut.plainKey);
    });

    test('updateUploaded', () {
      const sut = SyncObject(
        value: 10,
        changeState: 5,
        eTag: 'E-TAG',
        plainKey: 'key',
      );

      const newEtag = 'pdtd';
      final result = sut.updateUploaded(newEtag);
      expect(result.value, sut.value);
      expect(result.changeState, 0);
      expect(result.eTag, newEtag);
      expect(result.plainKey, sut.plainKey);
    });

    test('updateEtag', () {
      const sut = SyncObject(
        value: 10,
        changeState: 5,
        eTag: 'E-TAG',
        plainKey: 'key',
      );

      const newEtag = 'updated';
      final result = sut.updateEtag(newEtag);
      expect(result.value, sut.value);
      expect(result.changeState, sut.changeState);
      expect(result.eTag, newEtag);
      expect(result.plainKey, sut.plainKey);
    });
  });
}
