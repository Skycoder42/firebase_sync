import 'dart:async';

import 'package:firebase_database_rest/firebase_database_rest.dart';

abstract class WriteStoreRemote<T extends Object> {
  static const invalidETag = 'invalid_etag';

  const WriteStoreRemote._();
  Future<void> download([Filter? filter]);

  Future<void> upload({bool multipass = true});

  Future<void> reload({
    Filter? filter,
    bool multipass = true,
  });

  Future<StreamSubscription<void>> syncDownload({
    Filter? filter,
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  StreamSubscription<void> syncDownloadRenewed({
    FutureOr<Filter> Function()? onRenewFilter,
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  Future<StreamSubscription<void>> syncUpload({
    void Function()? onUpdate,
    Function? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });

  Future<String> create(T value);

  Future<void> destroy();
}
