import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_object.freezed.dart';

@freezed
class SyncObject<T extends Object> with _$SyncObject<T> {
  const SyncObject._();

  @Assert('changeState >= 0')
  const factory SyncObject({
    required T? value,
    @Default(0) int changeState,
    @Default(ApiConstants.nullETag) String eTag,
  }) = _SyncObject<T>;

  factory SyncObject.local(T value) => SyncObject(
        value: value,
        changeState: 1,
      );

  factory SyncObject.remote(T value, String eTag) => SyncObject(
        value: value,
        eTag: eTag,
      );

  bool get locallyModified => changeState > 0;

  SyncObject<T> updateLocal(T? value) => copyWith(
        value: value,
        changeState: changeState + 1,
      );

  SyncObject<T> updateUploaded(String eTag) => copyWith(
        changeState: 0,
        eTag: eTag,
      );
}
