import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_data.dart';

void main() {
  test('uses correct defaults', () {
    const entry = WriteStorageEntry<int>(value: null);

    expect(entry.value, null);
    expect(entry.eTag, ApiConstants.nullETag);
    expect(entry.localModifications, 0);
  });

  test('correctly creates local value', () {
    final res = WriteStorageEntry.local(10);

    expect(res.value, 10);
    expect(res.eTag, ApiConstants.nullETag);
    expect(res.localModifications, 1);
  });

  testData<Tuple2<int, bool>>('correctly reports modification state', const [
    Tuple2(0, false),
    Tuple2(1, true),
    Tuple2(10, true),
  ], (fixture) {
    final entry = WriteStorageEntry<int>(
      value: null,
      localModifications: fixture.item1,
    );

    expect(entry.isModified, fixture.item2);
  });

  group('updateLocal', () {
    const baseEntry = WriteStorageEntry(
      value: 10,
      eTag: 'TAG',
      localModifications: 5,
    );

    test('updates modifications', () {
      final res = baseEntry.updateLocal(20);

      expect(res.value, 20);
      expect(res.eTag, baseEntry.eTag);
      expect(res.localModifications, 6);
    });

    test('replaces eTag', () {
      final res = baseEntry.updateLocal(null, eTag: 'X');

      expect(res.value, null);
      expect(res.eTag, 'X');
      expect(res.localModifications, 6);
    });
  });
}
