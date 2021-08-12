import 'dart:typed_data';

import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_data.dart';

void main() {
  group('SyncObject', () {
    group('construction', () {
      test('SyncObject uses correct defaults', () {
        final sut = SyncObject<int>(
          value: null,
          changeState: 0,
          remoteTag: SyncObject.noRemoteDataTag,
        );

        expect(sut.value, isNull);
        expect(sut.changeState, 0);
        expect(sut.remoteTag, SyncObject.noRemoteDataTag);
      });

      testData<int>(
        'SyncObject asserts if changeState is invalid',
        const [
          -1,
          SyncObject.changeStateMax + 1,
        ],
        (fixture) {
          expect(
            () => SyncObject<int>(
              value: null,
              changeState: fixture,
              remoteTag: SyncObject.noRemoteDataTag,
            ),
            throwsA(isA<AssertionError>()),
          );
        },
      );

      testData<Uint8List>(
        'SyncObject asserts if remoteTag is invalid',
        [
          Uint8List(1),
          Uint8List(SyncObject.remoteTagMin - 1),
          Uint8List(SyncObject.remoteTagMax + 1),
        ],
        (fixture) {
          expect(
            () => SyncObject<int>(
              value: null,
              changeState: 0,
              remoteTag: fixture,
            ),
            throwsA(isA<AssertionError>()),
          );
        },
      );

      test('SyncObject.local initializes correctly', () {
        final sut = SyncObject<int>.local(42);

        expect(sut.value, 42);
        expect(sut.changeState, 1);
        expect(sut.remoteTag, SyncObject.noRemoteDataTag);
      });

      test('SyncObject.remote initializes correctly', () {
        final remoteTag = Uint8List.fromList(
          List.filled(SyncObject.remoteTagMin, 10),
        );
        final sut = SyncObject<int>.remote(
          13,
          remoteTag,
        );

        expect(sut.value, 13);
        expect(sut.changeState, 0);
        expect(sut.remoteTag, remoteTag);
      });

      test('SyncObject.deleted initializes correctly', () {
        final sut = SyncObject<int>.deleted();

        expect(sut.value, isNull);
        expect(sut.changeState, 0);
        expect(sut.remoteTag, SyncObject.noRemoteDataTag);
      });
    });

    group('members', () {
      group('updateLocal', () {
        final sut = SyncObject(
          value: 10,
          changeState: 5,
          remoteTag: Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index),
          ),
        );

        test('updates value and increments changeState', () {
          final result = sut.updateLocal(20);
          expect(result.value, 20);
          expect(result.changeState, 6);
          expect(result.remoteTag, sut.remoteTag);
        });

        test('overwrites remoteTag, if specified', () {
          final newRemoteTag = Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index + 5),
          );
          final result = sut.updateLocal(null, remoteTag: newRemoteTag);
          expect(result.value, isNull);
          expect(result.changeState, 6);
          expect(result.remoteTag, newRemoteTag);
        });
      });

      test('updateRemote', () {
        final sut = SyncObject(
          value: 10,
          changeState: 5,
          remoteTag: Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index + 11),
          ),
        );

        final newRemoteTag = Uint8List.fromList(
          List.generate(SyncObject.remoteTagMin, (index) => index + 9),
        );
        final result = sut.updateRemote(42, newRemoteTag);
        expect(result.value, 42);
        expect(result.changeState, 0);
        expect(result.remoteTag, newRemoteTag);
      });

      test('updateUploaded', () {
        final sut = SyncObject(
          value: 10,
          changeState: 5,
          remoteTag: Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index + 11),
          ),
        );

        final newRemoteTag = Uint8List.fromList(
          List.generate(SyncObject.remoteTagMin, (index) => index + 9),
        );
        final result = sut.updateUploaded(newRemoteTag);
        expect(result.value, sut.value);
        expect(result.changeState, 0);
        expect(result.remoteTag, newRemoteTag);
      });

      test('updateRemoteTag', () {
        final sut = SyncObject(
          value: 10,
          changeState: 5,
          remoteTag: Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index + 11),
          ),
        );

        final newRemoteTag = Uint8List.fromList(
          List.generate(SyncObject.remoteTagMin, (index) => index + 9),
        );
        final result = sut.updateRemoteTag(newRemoteTag);
        expect(result.value, sut.value);
        expect(result.changeState, sut.changeState);
        expect(result.remoteTag, newRemoteTag);
      });
    });
  });

  group('SyncObjectX', () {
    testData<Tuple2<int?, bool>>(
      'locallyModified returns true only if changeState == 0',
      const [
        Tuple2(null, false),
        Tuple2(0, false),
        Tuple2(1, true),
        Tuple2(10, true),
        Tuple2(42, true),
      ],
      (fixture) {
        final sut = fixture.item1 != null
            ? SyncObject(
                value: 0,
                changeState: fixture.item1!,
                remoteTag: SyncObject.noRemoteDataTag,
              )
            : null;
        expect(sut.locallyModified, fixture.item2);
      },
    );

    testData<Tuple2<Uint8List?, bool>>(
      'remotelyModified returns true only if remoteTag != noRemoteDataTag',
      [
        const Tuple2(null, false),
        Tuple2(Uint8List(0), false),
        Tuple2(Uint8List(SyncObject.remoteTagMin), true),
        Tuple2(Uint8List(SyncObject.remoteTagMax), true),
      ],
      (fixture) {
        final sut = fixture.item1 != null
            ? SyncObject(
                value: 0,
                changeState: 0,
                remoteTag: fixture.item1!,
              )
            : null;
        expect(sut.remotelyModified, fixture.item2);
      },
    );

    testData<Tuple2<Uint8List?, Uint8List>>(
      'remoteTagOrDefault remoteTag or noRemoteDataTag',
      [
        Tuple2(null, SyncObject.noRemoteDataTag),
        Tuple2(SyncObject.noRemoteDataTag, SyncObject.noRemoteDataTag),
        Tuple2(
          Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index),
          ),
          Uint8List.fromList(
            List.generate(SyncObject.remoteTagMin, (index) => index),
          ),
        ),
      ],
      (fixture) {
        final sut = fixture.item1 != null
            ? SyncObject(
                value: 0,
                changeState: 0,
                remoteTag: fixture.item1!,
              )
            : null;
        expect(sut.remoteTagOrDefault, fixture.item2);
      },
    );
  });
}
