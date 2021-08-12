import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_object.freezed.dart';

@freezed
class SyncObject<T extends Object> with _$SyncObject<T> {
  static const changeStateMax = 0xFFFFFFFF; // uint32 max
  static const remoteTagMin = 32;
  static const remoteTagMax = 0xFF; // uint8 max
  static final noRemoteDataTag = Uint8List(0);

  const SyncObject._(); // coverage:ignore-line

  @Assert(
    'changeState >= 0 && changeState <= SyncObject.changeStateMax',
    'changeState must be a valid uint32 value',
  )
  @Assert(
    'remoteTag.isEmpty || '
        '(remoteTag.length >= SyncObject.remoteTagMin && '
        'remoteTag.length <= SyncObject.remoteTagMax)',
    'remoteTag must be a valid uint8 value that is either empty '
        '(noRemoteDataTag) or has at least $remoteTagMin bytes',
  )
  factory SyncObject({
    required T? value,
    required int changeState,
    required Uint8List remoteTag,
  }) = _SyncObject<T>;

  factory SyncObject.local(T value) => SyncObject(
        value: value,
        changeState: 1,
        remoteTag: noRemoteDataTag,
      );

  factory SyncObject.remote(T value, Uint8List remoteTag) => SyncObject(
        value: value,
        changeState: 0,
        remoteTag: remoteTag,
      );

  factory SyncObject.deleted() => SyncObject(
        value: null,
        changeState: 0,
        remoteTag: noRemoteDataTag,
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

  SyncObject<T> updateRemoteTag(Uint8List remoteTag) => copyWith(
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
