import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../store/sync_object.dart';
import '../../store/update_action.dart';
import '../sync_job.dart';
import '../sync_node.dart';

mixin ConflictResolverMixin<T extends Object> on SyncJob {
  @visibleForOverriding
  SyncNode<T> get syncNode;

  @protected
  UpdateAction<SyncObject<T>> resolveConflict({
    required String key,
    required SyncObject<T> localData,
    required T? remoteData,
    required Uint8List remoteTag,
  }) {
    assert(localData.locallyModified);
    assert(localData.remoteTagOrDefault != remoteTag);

    return syncNode.conflictResolver
        .resolve(
          key,
          local: localData.value,
          remote: remoteData,
        )
        .when(
          local: () => UpdateAction.update(
            localData.updateRemoteTag(remoteTag),
          ),
          remote: () {
            if (remoteData == null) {
              return const UpdateAction.delete();
            } else {
              return UpdateAction.update(
                localData.updateRemote(remoteData, remoteTag),
              );
            }
          },
          delete: () {
            if (remoteData == null) {
              return const UpdateAction.delete();
            } else {
              return UpdateAction.update(
                localData.updateLocal(null, remoteTag: remoteTag),
              );
            }
          },
          update: (updated) => UpdateAction.update(
            localData.updateLocal(updated, remoteTag: remoteTag),
          ),
        );
  }
}
