import 'dart:io';

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
}
