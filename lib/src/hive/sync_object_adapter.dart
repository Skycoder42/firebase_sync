import 'package:hive/hive.dart';

import '../core/store/sync_object.dart';

class SyncObjectAdapter<T extends Object>
    implements TypeAdapter<SyncObject<T>> {
  final TypeAdapter<T> contentAdapter;
  final bool writePlainKeys;

  SyncObjectAdapter({
    required this.contentAdapter,
    required this.writePlainKeys,
  });

  @override
  int get typeId => contentAdapter.typeId;

  @override
  SyncObject<T> read(BinaryReader reader) => SyncObject(
        changeState: reader.readUint32(),
        remoteTag: reader.readByteList(reader.readByte()),
        plainKey: writePlainKeys ? reader.readString() : null,
        value: reader.availableBytes > 0 ? contentAdapter.read(reader) : null,
      );

  @override
  void write(BinaryWriter writer, SyncObject<T> obj) {
    writer
      ..writeUint32(obj.changeState)
      ..writeByte(obj.remoteTag.length)
      ..writeByteList(obj.remoteTag, writeLength: false);
    if (writePlainKeys) {
      writer.writeString(obj.plainKey!);
    }
    if (obj.value != null) {
      contentAdapter.write(writer, obj.value!);
    }
  }
}
