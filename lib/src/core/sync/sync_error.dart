import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_error.freezed.dart';

@freezed
class SyncError with _$SyncError {
  const factory SyncError.uncaught(
    Object error, [
    StackTrace? stackTrace,
  ]) = _Uncaught;

  const factory SyncError.stream({
    required Object error,
    required Type stream,
    StackTrace? stackTrace,
  }) = _Stream;

  const factory SyncError.job({
    required Object error,
    required String storeName,
    required String key,
    StackTrace? stackTrace,
  }) = _Job;
}
