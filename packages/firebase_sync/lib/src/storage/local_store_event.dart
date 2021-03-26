// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_store_event.freezed.dart';

@freezed
class LocalStoreEvent<T extends Object> with _$LocalStoreEvent<T> {
  const factory LocalStoreEvent.update(String key, T value) = _Update<T>;
  const factory LocalStoreEvent.delete(String key) = _Delete<T>;
}
