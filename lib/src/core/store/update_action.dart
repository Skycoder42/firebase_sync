import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_action.freezed.dart';

@freezed
class UpdateAction<T extends Object> with _$UpdateAction<T> {
  const factory UpdateAction.none() = _None<T>;
  const factory UpdateAction.update(T value) = _Update<T>;
  const factory UpdateAction.delete() = _Delete<T>;
}
