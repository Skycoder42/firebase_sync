import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'write_storage_entry.freezed.dart';

@freezed
class WriteStorageEntry<T extends Object> with _$WriteStorageEntry<T> {
  const factory WriteStorageEntry({
    required T? value,
    @Default(ApiConstants.nullETag) String eTag,
    @Default(0) int localModifications,
  }) = _WriteStorageEntry<T>;
}
