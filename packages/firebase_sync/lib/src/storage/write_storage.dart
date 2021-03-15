import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'storage.dart';

part 'write_storage.freezed.dart';

@freezed
class ValueUpdate<T> with _$ValueUpdate<T> {
  const ValueUpdate._();

  // ignore: sort_unnamed_constructors_first
  const factory ValueUpdate(T value) = _Value<T>;
  @Assert('T is int')
  const factory ValueUpdate.increment() = _Increment<T>;

  T get asValue => when(
        (value) => value,
        increment: () => throw StateError(
          'Cannot call asValue on ValueUpdate.increment',
        ),
      );
}

abstract class WriteStorageEntry<T extends Object> {
  T? get value;
  String get eTag;
  int get localModifications;

  WriteStorageEntry<T> update({
    ValueUpdate<T?>? value,
    ValueUpdate<String>? eTag,
    ValueUpdate<int>? localModifications,
  });
}

abstract class WriteStorage<T extends Object>
    implements Storage<WriteStorageEntry<T>> {
  const WriteStorage._();

  WriteStorageEntry<T> createEntry({
    required T? value,
    String eTag = ApiConstants.nullETag,
    int localModifications = 0,
  });
}
