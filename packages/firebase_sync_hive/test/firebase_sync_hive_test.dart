import 'dart:io';
import 'dart:math';

import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

void main() {
  test('tryouts', () async {
    Hive.init(Directory.systemTemp.createTempSync().path);

    final box1 = await Hive.openBox<int>('test');
    final box2 = Hive.box<int>('test');
    final box3 = Hive.box<int>('test');

    // ignore: unawaited_futures
    box1.put(1, 1);
    expect(box2.get(1), 1);
    expect(box3.get(1), 1);

    expect(box1, box2);
    expect(box1, box3);
    expect(box2, box3);
  });

  test('type detection', () {
    void tVerifyX<T1, T2>(Matcher matcher) => expect(
          T1 == T2,
          matcher,
          reason: '$T1 == $T2',
        );

    const x = WriteStorageEntry<int>(value: 42);
    const dynamic dynX = x as dynamic;
    expect(x is WriteStorageEntry<int>, isTrue);
    expect(x is WriteStorageEntry<dynamic>, isTrue);
    expect(x is WriteStorageEntry, isTrue);
    tVerifyX<WriteStorageEntry<int>, WriteStorageEntry<int>>(isTrue);
    tVerifyX<WriteStorageEntry<int>, WriteStorageEntry<dynamic>>(isFalse);
    tVerifyX<WriteStorageEntry<int>, WriteStorageEntry>(isFalse);
    expect(dynX is WriteStorageEntry, isTrue);
    expect(dynX as WriteStorageEntry, isNotNull);
  });
}
