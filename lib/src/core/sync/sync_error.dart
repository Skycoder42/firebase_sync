import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_error.freezed.dart';

@freezed
class SyncError with _$SyncError {
  const SyncError._();

  const factory SyncError(
    Object error, [
    StackTrace? stackTrace,
  ]) = _SyncError;

  @visibleForTesting
  const factory SyncError.named({
    required String name,
    required Object error,
    StackTrace? stackTrace,
  }) = NamedSyncError;

  @internal
  NamedSyncError named(String name) => map(
        (error) => NamedSyncError(
          name: name,
          error: error.error,
          stackTrace: error.stackTrace,
        ),
        named: (_) => throw UnsupportedError(
          'Cannot call named() on an already named error',
        ),
      );

  // coverage:ignore-start
  @override
  String toString() => '$error${stackTrace != null ? '\n$stackTrace' : ''}';
  // coverage:ignore-end
}
