import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_object.freezed.dart';

@internal
enum ChangeState {
  unchanged,
  modified,
  uploading,
}

@freezed
@internal
class SyncObject<T extends Object> with _$SyncObject<T> {
  const SyncObject._();

  // ignore: sort_unnamed_constructors_first
  const factory SyncObject({
    required T? value,
    @Default(ChangeState.unchanged) ChangeState changeState,
    @Default(ApiConstants.nullETag) String eTag,
  }) = _SyncObject<T>;

  factory SyncObject.local(T value) => SyncObject(
        value: value,
        changeState: ChangeState.modified,
      );

  SyncObject<T> updateLocal(T? value) => copyWith(
        value: value,
        changeState: ChangeState.modified,
      );
}
