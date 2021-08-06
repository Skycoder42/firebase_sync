import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_error.freezed.dart';

@freezed
class SyncError with _$SyncError {
  const SyncError._();

  const factory SyncError.uncaught(
    Object error, [
    StackTrace? stackTrace,
  ]) = _Uncaught;

  const factory SyncError.stream({
    required Object error,
    StackTrace? stackTrace,
    required String source,
  }) = _Stream;

  const factory SyncError.job({
    required Object error,
    StackTrace? stackTrace,
    required String storeName,
    required String key,
  }) = _Job;

  // coverage:ignore-start
  @override
  String toString() => '${when(
        uncaught: (e, s) => 'SyncError.uncaught',
        stream: (e, s, source) => 'SyncError.stream($source)',
        job: (e, s, storeName, key) => 'SyncError.job($storeName:$key)',
      )}${': $error${stackTrace != null ? '\n$stackTrace' : ''}'}';
  // coverage:ignore-end
}
