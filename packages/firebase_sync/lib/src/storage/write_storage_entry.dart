import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'write_storage_entry.freezed.dart';

@freezed
class WriteStorageEntry<T extends Object> with _$WriteStorageEntry<T> {
  const WriteStorageEntry._();

  // ignore: sort_unnamed_constructors_first
  const factory WriteStorageEntry({
    required T? value,
    @Default(ApiConstants.nullETag) String eTag,
    @Default(0) int localModifications,
  }) = _WriteStorageEntry<T>;

  factory WriteStorageEntry.local(T? value) => WriteStorageEntry(
        value: value,
        localModifications: 1,
      );

  bool get isModified => localModifications > 0;

  WriteStorageEntry<T> updateLocal(
    T? value, {
    String? eTag,
  }) =>
      copyWith(
        value: value,
        localModifications: localModifications + 1,
        eTag: eTag ?? this.eTag,
      );
}
