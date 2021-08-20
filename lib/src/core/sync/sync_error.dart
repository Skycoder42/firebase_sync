import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_error.freezed.dart';

@freezed
class SyncError with _$SyncError {
  const SyncError._();

  const factory SyncError(
    Object error, [
    StackTrace? stackTrace,
  ]) = _SyncError;

  // coverage:ignore-start
  @override
  String toString() => '$error${stackTrace != null ? '\n$stackTrace' : ''}';
  // coverage:ignore-end
}
