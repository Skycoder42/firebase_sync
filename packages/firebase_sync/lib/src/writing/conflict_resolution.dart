import 'package:freezed_annotation/freezed_annotation.dart';

part 'conflict_resolution.freezed.dart';

@freezed
class ConflictResolution<T> with _$ConflictResolution<T> {
  const factory ConflictResolution.local() = _Local;
  const factory ConflictResolution.remote() = _Remote;
  const factory ConflictResolution.delete() = _Delete;
  const factory ConflictResolution.update(T data) = _Update;
}
