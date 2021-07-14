import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_event.freezed.dart';

@freezed
class StoreEvent<T extends Object> with _$StoreEvent<T> {
  const factory StoreEvent({
    required String key,
    required T? value,
  }) = _StoreEvent<T>;
}
