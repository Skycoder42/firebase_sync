import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

extension BoxBaseX<T> on BoxBase<T> {
  String generateKey(Uuid uuid) {
    String key;
    do {
      key = uuid.v4();
    } while (containsKey(key));
    return key;
  }
}
