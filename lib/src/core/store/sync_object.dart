import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_object.freezed.dart';

@freezed
class SyncObject<T extends Object> with _$SyncObject<T> {
  static const changeStateMax = 0xFFFFFFFF;
  static const remoteTagMin = 32;
  static const remoteTagMax = 0xFF;
  static final noRemoteDataTag = Uint8List(0); // TODO optional getter extension

  const SyncObject._(); // coverage:ignore-line

  @Assert(
    'changeState >= 0 && changeState <= SyncObject.changeStateMax',
    'changeState must be a valid uint32 value',
  )
  @Assert(
    'remoteTag.isEmpty || '
        '(remoteTag.length >= SyncObject.remoteTagMin && '
        'remoteTag.length <= SyncObject.remoteTagMax)',
    'remoteTag must be either noRemoteDataTag or have at least 32 bytes',
  )
  const factory SyncObject({
    required T? value,
    required int changeState,
    required Uint8List remoteTag,
    String? plainKey,
  }) = _SyncObject<T>;

  factory SyncObject.local(
    T value, {
    String? plainKey,
  }) =>
      SyncObject(
        value: value,
        changeState: 1,
        remoteTag: noRemoteDataTag,
        plainKey: plainKey,
      );

  factory SyncObject.remote(
    T value,
    Uint8List remoteTag, {
    String? plainKey,
  }) =>
      SyncObject(
        value: value,
        changeState: 0,
        remoteTag: remoteTag,
        plainKey: plainKey,
      );

  factory SyncObject.deleted({
    String? plainKey,
  }) =>
      SyncObject(
        value: null,
        changeState: 0,
        remoteTag: noRemoteDataTag,
        plainKey: plainKey,
      );

  SyncObject<T> updateLocal(T? value, {Uint8List? remoteTag}) => copyWith(
        value: value,
        changeState: _safeIncrement(changeState),
        remoteTag: remoteTag ?? this.remoteTag,
      );

  SyncObject<T> updateRemote(T? value, Uint8List remoteTag) => copyWith(
        value: value,
        remoteTag: remoteTag,
        changeState: 0,
      );

  SyncObject<T> updateUploaded(Uint8List remoteTag) => copyWith(
        changeState: 0,
        remoteTag: remoteTag,
      );

  SyncObject<T> updateRemoteTag(Uint8List eTag) => copyWith(
        remoteTag: remoteTag,
      );

  // coverage:ignore-start
  @override
  @visibleForTesting
  $SyncObjectCopyWith<T, SyncObject<T>> get copyWith => super.copyWith;
  // coverage:ignore-end

  int _safeIncrement(int value) => value >= changeStateMax ? 0 : value + 1;
}

extension SyncObjectX on SyncObject? {
  bool get locallyModified => (this?.changeState ?? 0) > 0;

  bool get remotelyModified => this?.remoteTag.isNotEmpty ?? false;

  Uint8List get remoteTagOrDefault =>
      this?.remoteTag ?? SyncObject.noRemoteDataTag;
}
