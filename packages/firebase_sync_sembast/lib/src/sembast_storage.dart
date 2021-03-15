import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:sembast/sembast.dart';

import 'sembast_storage_raw.dart';

class SembastStorage<T extends Object> extends JsonStorage<T> {
  SembastStorage({
    required Database database,
    required StoreRef<String, Object> storeRef,
    required JsonConverter<T> jsonConverter,
  }) : super(
          jsonConverter: jsonConverter,
          rawStorage: SembastStorageRaw.database(
            database: database,
            storeRef: storeRef,
          ),
        );

  @override
  SembastStorageRaw<Object> get rawStorage =>
      super.rawStorage as SembastStorageRaw<Object>;

  Future<Map<String, T>> query(Finder finder) async {
    final entries = await rawStorage.query(finder);
    return entries.map(
      (key, value) => MapEntry(
        key,
        jsonConverter.dataFromJson(value),
      ),
    );
  }
}

extension StoreRefX on StoreRef<String, Object> {
  SembastStorage<T> storage<T extends Object>({
    required Database database,
    required JsonConverter<T> jsonConverter,
  }) =>
      SembastStorage(
        database: database,
        storeRef: this,
        jsonConverter: jsonConverter,
      );
}
