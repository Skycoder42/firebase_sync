import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/store.dart';

@internal
mixin SyncMixin<T extends Object> implements Store<T> {
  @visibleForOverriding
  SyncStore<T> get syncStore;
}
