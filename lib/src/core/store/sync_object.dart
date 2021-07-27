import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_object.freezed.dart';

@freezed
class SyncObject<T extends Object> with _$SyncObject<T> {
  const SyncObject._(); // coverage:ignore-line

  @visibleForTesting
  @Assert('changeState >= 0')
  const factory SyncObject({
    required T? value,
    @Default(0) int changeState,
    @Default(ApiConstants.nullETag) String eTag,
    String? plainKey,
  }) = _SyncObject<T>;

  factory SyncObject.local(
    T value, {
    String? plainKey,
  }) =>
      SyncObject(
        value: value,
        changeState: 1,
        plainKey: plainKey,
      );

  factory SyncObject.remote(
    T value,
    String eTag, {
    String? plainKey,
  }) =>
      SyncObject(
        value: value,
        eTag: eTag,
        plainKey: plainKey,
      );

  factory SyncObject.deleted({
    String? plainKey,
  }) =>
      SyncObject(
        value: null,
        plainKey: plainKey,
      );

  bool get locallyModified => changeState > 0;

  SyncObject<T> updateLocal(T? value, {String? eTag}) => copyWith(
        value: value,
        changeState: changeState + 1,
        eTag: eTag ?? this.eTag,
      );

  SyncObject<T> updateRemote(T? value, String eTag) => copyWith(
        value: value,
        eTag: eTag,
      );

  SyncObject<T> updateUploaded(String eTag) => copyWith(
        changeState: 0,
        eTag: eTag,
      );

  SyncObject<T> updateEtag(String eTag) => copyWith(
        eTag: eTag,
      );

  // coverage:ignore-start
  @override
  @visibleForTesting
  $SyncObjectCopyWith<T, SyncObject<T>> get copyWith => super.copyWith;
  // coverage:ignore-end
}
