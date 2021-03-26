import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:freezed_annotation/freezed_annotation.dart' hide JsonConverter;

import '../../firebase_sync.dart';

part 'storage_factory.freezed.dart';

@freezed
class ExtraArgInfo with _$ExtraArgInfo {
  const ExtraArgInfo._();

  // ignore: sort_unnamed_constructors_first
  const factory ExtraArgInfo({
    required String name,
    required Type type,
    @Default(null) dynamic defaultValue,
    String? description,
  }) = _ExtraArgInfo;

  static ExtraArgInfo create<T>({
    required String name,
    required T defaultValue,
    String? description,
  }) =>
      ExtraArgInfo(
        name: name,
        type: T,
        defaultValue: defaultValue,
        description: description,
      );

  T extractArg<T>(Map<String, dynamic> args) {
    assert(T == type, 'Can only extract type');
    return (args[name] as T?) ?? (defaultValue as T);
  }
}

abstract class StorageFactory {
  const StorageFactory._(); // coverage:ignore-line

  bool get canCreateSyncStore;

  Iterable<ExtraArgInfo> get extraArgs;

  Storage<T> createStorage<T extends Object>({
    required String firebasePath,
    required JsonConverter<T> jsonConverter,
    bool sync = false,
    Map<String, dynamic> extraArgs = const <String, dynamic>{},
  });
}
