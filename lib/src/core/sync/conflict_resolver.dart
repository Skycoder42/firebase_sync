import 'package:freezed_annotation/freezed_annotation.dart';

part 'conflict_resolver.freezed.dart';

@freezed
class ConflictResolution<T> with _$ConflictResolution<T> {
  const factory ConflictResolution.local() = _Local;
  const factory ConflictResolution.remote() = _Remote;
  const factory ConflictResolution.delete() = _Delete;
  const factory ConflictResolution.update(T data) = _Update;
}

abstract class ConflictResolver<T extends Object> {
  const factory ConflictResolver() = _DefaultConflictResolver<T>;

  ConflictResolution<T> resolve(
    String key, {
    required T? local,
    required T? remote,
  });
}

class _DefaultConflictResolver<T extends Object>
    implements ConflictResolver<T> {
  const _DefaultConflictResolver();

  @override
  ConflictResolution<T> resolve(
    String key, {
    required T? local,
    required T? remote,
  }) =>
      const ConflictResolution.remote();
}
