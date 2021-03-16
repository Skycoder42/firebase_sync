import 'package:firebase_database_rest/firebase_database_rest.dart';

import 'write_storage_entry.dart';

class WriteStorageEntryJsonConverter<T extends Object>
    implements JsonConverter<WriteStorageEntry<T>> {
  final JsonConverter<T> jsonConverter;

  const WriteStorageEntryJsonConverter(this.jsonConverter);

  @override
  WriteStorageEntry<T> dataFromJson(covariant Map<String, dynamic> json) =>
      WriteStorageEntry(
        value: json['value'] != null
            ? jsonConverter.dataFromJson(json['value'])
            : null,
        eTag: json['eTag'] as String,
        localModifications: json['localModifications'] as int,
      );

  @override
  dynamic dataToJson(WriteStorageEntry<T> data) => <String, dynamic>{
        'value':
            data.value != null ? jsonConverter.dataToJson(data.value!) : null,
        'eTag': data.eTag,
        'localModifications': data.localModifications,
      };

  @override
  WriteStorageEntry<T> patchData(
    WriteStorageEntry<T> data,
    Map<String, dynamic> updatedFields,
  ) =>
      data.copyWith(
        value: jsonConverter.patchData(data.value!, updatedFields),
      );
}
