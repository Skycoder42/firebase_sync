import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart' hide JsonConverter;

import 'json_storage.dart';
import 'write_storage.dart';

part 'json_write_storage.freezed.dart';

@freezed
class _JsonWriteStorageEntry<T extends Object>
    with _$_JsonWriteStorageEntry<T>
    implements WriteStorageEntry<T> {
  const factory _JsonWriteStorageEntry({
    required T? value,
    required String eTag,
    required int localModifications,
  }) = _Entry;

  @override
  _JsonWriteStorageEntry<T> update({
    ValueUpdate<T?>? value,
    ValueUpdate<String>? eTag,
    ValueUpdate<int>? localModifications,
  }) =>
      (this as dynamic).copyWith(
        value: value?.asValue ?? freezed,
        eTag: eTag?.asValue ?? freezed,
        localModifications: localModifications?.when(
              (value) => value,
              increment: () => this.localModifications + 1,
            ) ??
            freezed,
      ) as _JsonWriteStorageEntry<T>;
}

class _WriteStorageJsonConverter<T extends Object>
    implements JsonConverter<_JsonWriteStorageEntry<T>> {
  final JsonConverter<T> jsonConverter;

  const _WriteStorageJsonConverter(this.jsonConverter);

  @override
  _JsonWriteStorageEntry<T> dataFromJson(covariant Map<String, dynamic> json) =>
      _JsonWriteStorageEntry(
        value: json['value'] != null
            ? jsonConverter.dataFromJson(json['value'])
            : null,
        eTag: json['eTag'] as String,
        localModifications: json['localModifications'] as int,
      );

  @override
  dynamic dataToJson(_JsonWriteStorageEntry<T> data) => <String, dynamic>{
        'value':
            data.value != null ? jsonConverter.dataToJson(data.value!) : null,
        'eTag': data.eTag,
        'localModifications': data.localModifications,
      };

  @override
  _JsonWriteStorageEntry<T> patchData(
    _JsonWriteStorageEntry<T> data,
    Map<String, dynamic> updatedFields,
  ) =>
      data.copyWith(
        value: jsonConverter.patchData(data.value!, updatedFields),
      );
}

class JsonWriteStorage<T extends Object>
    extends JsonStorage<WriteStorageEntry<T>> implements WriteStorage<T> {
  JsonWriteStorage({
    required WriteStorage<T> rawStorage,
    required JsonConverter<T> jsonConverter,
  }) : super(
          rawStorage: rawStorage,
          jsonConverter: _WriteStorageJsonConverter(jsonConverter),
        );

  @override
  WriteStorageEntry<T> createEntry({
    required T? value,
    String eTag = ApiConstants.nullETag,
    int localModifications = 0,
  }) =>
      _JsonWriteStorageEntry(
        value: value,
        eTag: eTag,
        localModifications: localModifications,
      );
}
