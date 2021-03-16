import 'package:firebase_sync/firebase_sync.dart';
import 'package:hive/hive.dart';

class WriteStorageEntryTypeAdapter<T extends Object>
    implements TypeAdapter<WriteStorageEntry<T>> {
  static const int version = 1;

  @override
  final int typeId;

  const WriteStorageEntryTypeAdapter(this.typeId);

  WriteStorageEntryTypeAdapter.wrap(TypeAdapter<T> rawAdapter)
      : assert(
          rawAdapter.typeId < 100,
          'Can only wrap adapters with a typeId of below 100',
        ),
        typeId = 100 + rawAdapter.typeId;

  @override
  WriteStorageEntry<T> read(BinaryReader reader) {
    final storedVersion = reader.readByte();
    switch (storedVersion) {
      case version:
        return WriteStorageEntry(
          value: reader.read() as T?,
          eTag: reader.readString(),
          localModifications: reader.readInt(),
        );
      default:
        throw UnimplementedError(); // TODO real exception
    }
  }

  @override
  void write(BinaryWriter writer, WriteStorageEntry<T> obj) => writer
    ..writeByte(version)
    ..write(obj.value)
    ..writeString(obj.eTag)
    ..writeInt(obj.localModifications);
}
