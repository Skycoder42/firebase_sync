import 'package:firebase_database_rest/firebase_database_rest.dart';

import 'cipher_message.dart';

class CryptoFirebaseStore extends FirebaseStore<CipherMessage> {
  CryptoFirebaseStore({
    required FirebaseStore<dynamic> parent,
    required String name,
  }) : super(
          parent: parent,
          path: name,
        );

  @override
  CipherMessage dataFromJson(dynamic json) =>
      CipherMessage.fromJson(json as Map<String, dynamic>);

  @override
  dynamic dataToJson(CipherMessage data) => data.toJson();

  @override
  CipherMessage patchData(
    CipherMessage data,
    Map<String, dynamic> updatedFields,
  ) =>
      throw UnsupportedError(
        'Cannot run patch operations on CryptoFirebaseStore instances',
      );
}
