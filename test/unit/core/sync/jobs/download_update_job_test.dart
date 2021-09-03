// ignore_for_file: invalid_use_of_protected_member
import 'dart:typed_data';

import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/src/core/crypto/cipher_message.dart';
import 'package:firebase_sync/src/core/crypto/crypto_firebase_store.dart';
import 'package:firebase_sync/src/core/crypto/data_encryptor.dart';
import 'package:firebase_sync/src/core/store/sync_object.dart';
import 'package:firebase_sync/src/core/store/sync_object_store.dart';
import 'package:firebase_sync/src/core/store/update_action.dart';
import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:firebase_sync/src/core/sync/executable_sync_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/download_update_job.dart';
import 'package:firebase_sync/src/core/sync/jobs/upload_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockCryptoFirebaseStore extends Mock implements CryptoFirebaseStore {}

class MockDataEncryptor extends Mock implements DataEncryptor {}

class MockJsonConverter extends Mock implements JsonConverter<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class MockConflictResolver extends Mock implements ConflictResolver<int> {}

class MockCipherMessage extends Mock implements CipherMessage {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue<CipherMessage>(MockCipherMessage());
  });

  group('DownloadUpdateJob', () {
    const key = 'update-key';
    final testUri = Uri.https('example.com', '/test');
    const testJson = '{}';

    final mockSyncNode = MockSyncNode();
    final mockCryptoFirebaseStore = MockCryptoFirebaseStore();
    final mockDataEncryptor = MockDataEncryptor();
    final mockJsonConverter = MockJsonConverter();
    final mockSyncObjectStore = MockSyncObjectStore();
    final mockConflictResolver = MockConflictResolver();
    final mockCipherMessage = MockCipherMessage();

    late DownloadUpdateJob<int> sut;

    void whenUpdate({
      required int remoteData,
      required Uint8List remoteTag,
      required SyncObject<int>? oldData,
      required SyncObject<int>? newData,
      required dynamic resultMatcher,
    }) {
      when(() => mockJsonConverter.dataFromJson(any<dynamic>()))
          .thenReturn(remoteData);
      when(() => mockCipherMessage.remoteTag).thenReturn(remoteTag);
      when(() => mockSyncObjectStore.update(any(), any())).thenAnswer((i) {
        final callback = i.positionalArguments[1] as UpdateFn<int>;
        final result = callback(oldData);
        expect(result, resultMatcher);
        return newData;
      });
    }

    setUp(() {
      reset(mockSyncNode);
      reset(mockCryptoFirebaseStore);
      reset(mockDataEncryptor);
      reset(mockJsonConverter);
      reset(mockSyncObjectStore);
      reset(mockConflictResolver);
      reset(mockCipherMessage);

      when(() => mockSyncNode.remoteStore).thenReturn(mockCryptoFirebaseStore);
      when(() => mockSyncNode.dataEncryptor).thenReturn(mockDataEncryptor);
      when(() => mockSyncNode.jsonConverter).thenReturn(mockJsonConverter);
      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);
      when(() => mockSyncNode.conflictResolver)
          .thenReturn(mockConflictResolver);

      when(() => mockCryptoFirebaseStore.remoteUri(any())).thenReturn(testUri);
      when(
        () => mockDataEncryptor.decrypt(
          remoteUri: any(named: 'remoteUri'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((i) async => testJson);

      sut = DownloadUpdateJob(
        key: key,
        remoteCipher: mockCipherMessage,
        syncNode: mockSyncNode,
        conflictsTriggerUpload: true,
      );
    });

    group('executeImpl', () {
      test('decrypts and decodes remote data', () async {
        const testData = 111;

        whenUpdate(
          remoteData: testData,
          remoteTag: SyncObject.noRemoteDataTag,
          oldData: null,
          newData: null,
          resultMatcher: anything,
        );

        await sut.executeImpl();

        verifyInOrder([
          () => mockCryptoFirebaseStore.remoteUri(key),
          () => mockDataEncryptor.decrypt(
                remoteUri: testUri,
                data: mockCipherMessage,
              ),
          () => mockJsonConverter.dataFromJson(testJson),
        ]);
      });

      test('uses remote data if no local data present', () async {
        const remoteData = 45;
        final remoteTag = Uint8List.fromList(List.generate(
          SyncObject.remoteTagMin,
          (index) => 30 + index,
        ));
        final newData = SyncObject.remote(remoteData, remoteTag);

        whenUpdate(
          remoteData: remoteData,
          remoteTag: remoteTag,
          oldData: null,
          newData: newData,
          resultMatcher: UpdateAction.update(newData),
        );

        final result = await sut.executeImpl();

        expect(result, const ExecutionResult.modified());
        verify(() => mockSyncObjectStore.update(key, any()));
      });

      test('does nothing if remote data tags are equal', () async {
        const remoteData = 45;
        final remoteTag = Uint8List.fromList(List.generate(
          SyncObject.remoteTagMin,
          (index) => 30 + index,
        ));
        final oldData = SyncObject(
          value: 90,
          changeState: 1,
          remoteTag: remoteTag,
        );

        whenUpdate(
          remoteData: remoteData,
          remoteTag: remoteTag,
          oldData: oldData,
          newData: oldData,
          resultMatcher: const UpdateAction.none(),
        );

        final result = await sut.executeImpl();

        expect(result, const ExecutionResult.noop());
        verify(() => mockSyncObjectStore.update(key, any()));
      });

      test('replaces local with remote data if it was not modified', () async {
        const remoteData = 45;
        final remoteTag = Uint8List.fromList(List.generate(
          SyncObject.remoteTagMin,
          (index) => 30 + index,
        ));
        final newData = SyncObject.remote(remoteData, remoteTag);

        whenUpdate(
          remoteData: remoteData,
          remoteTag: remoteTag,
          oldData: SyncObject(
            value: 20,
            changeState: 0,
            remoteTag: SyncObject.noRemoteDataTag,
          ),
          newData: newData,
          resultMatcher: UpdateAction.update(newData),
        );

        final result = await sut.executeImpl();

        expect(result, const ExecutionResult.modified());
        verify(() => mockSyncObjectStore.update(key, any()));
      });

      test('resolves conflicts hand triggers upload if required', () async {
        final remoteTag = Uint8List.fromList(
          List.filled(SyncObject.remoteTagMin, 10),
        );
        final newData = SyncObject<int>(
          value: null,
          changeState: 6,
          remoteTag: remoteTag,
        );

        when(
          () => mockConflictResolver.resolve(
            any(),
            local: any(named: 'local'),
            remote: any(named: 'remote'),
          ),
        ).thenReturn(const ConflictResolution.delete());

        whenUpdate(
          remoteData: 42,
          remoteTag: remoteTag,
          oldData: SyncObject(
            value: 10,
            changeState: 5,
            remoteTag: Uint8List(SyncObject.remoteTagMin),
          ),
          newData: newData,
          resultMatcher: UpdateAction.update(newData),
        );

        final result = await sut.executeImpl();

        result.maybeWhen(
          orElse: () =>
              fail('Expected ExecutionResult.continued, but got $result'),
          continued: (job) => expect(
            job,
            isA<UploadJob<int>>()
                .having((j) => j.key, 'key', key)
                .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                .having((j) => j.multipass, 'multipass', isFalse),
          ),
        );

        verify(() => mockSyncObjectStore.update(key, any()));
        verify(
          () => mockConflictResolver.resolve(
            key,
            local: 10,
            remote: 42,
          ),
        );
      });
    });
  });
}
