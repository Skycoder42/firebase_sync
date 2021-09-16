// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
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
import 'package:firebase_sync/src/core/sync/jobs/upload_job.dart';
import 'package:firebase_sync/src/core/sync/sync_node.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../../test_data.dart';

class MockSyncNode extends Mock implements SyncNode<int> {}

class MockSyncObjectStore extends Mock implements SyncObjectStore<int> {}

class MockCryptoFirebaseStore extends Mock implements CryptoFirebaseStore {}

class MockDataEncryptor extends Mock implements DataEncryptor {}

class MockJsonConverter extends Mock implements JsonConverter<int> {}

class MockConflictResolver extends Mock implements ConflictResolver<int> {}

class MockTransaction extends Mock
    implements FirebaseTransaction<CipherMessage> {}

class FakeCipherMessage extends Fake implements CipherMessage {
  @override
  final Uint8List remoteTag;

  FakeCipherMessage([Uint8List? remoteTag])
      : remoteTag = remoteTag ?? SyncObject.noRemoteDataTag;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeCipherMessage());
  });

  group('UploadJob', () {
    const key = 'upload-key';
    final uri = Uri(scheme: 'test', host: key);
    const jsonData = '{"data": true}';

    final mockSyncNode = MockSyncNode();
    final mockSyncObjectStore = MockSyncObjectStore();
    final mockCryptoFirebaseStore = MockCryptoFirebaseStore();
    final mockDataEncryptor = MockDataEncryptor();
    final mockJsonConverter = MockJsonConverter();
    final mockConflictResolver = MockConflictResolver();
    final mockTransaction = MockTransaction();

    When<Future<CipherMessage>> whenEncrypt() => when(
          () => mockDataEncryptor.encrypt(
            remoteUri: any(named: 'remoteUri'),
            dataJson: any<dynamic>(named: 'dataJson'),
          ),
        );

    void whenTransact([Uint8List? remoteTag]) =>
        when(() => mockTransaction.value)
            .thenReturn(FakeCipherMessage(remoteTag));

    void whenUpdate({
      required SyncObject<int>? oldData,
      required SyncObject<int>? newData,
      required dynamic resultMatcher,
    }) {
      when(() => mockSyncObjectStore.update(any(), any())).thenAnswer((i) {
        final callback = i.positionalArguments[1] as UpdateFn<int>;
        final result = callback(oldData);
        expect(result, resultMatcher);
        return newData;
      });
    }

    void whenUpdateMany(
      List<Tuple3<SyncObject<int>?, SyncObject<int>?, dynamic>> elements,
    ) {
      assert(elements.isNotEmpty);

      var invokationCnt = 0;
      final doneCompleter = Completer<void>();
      when(() => mockSyncObjectStore.update(any(), any())).thenAnswer((i) {
        final data = elements[invokationCnt++];
        if (invokationCnt == elements.length) {
          doneCompleter.complete();
        }

        final callback = i.positionalArguments[1] as UpdateFn<int>;
        final result = callback(data.item1);
        expect(result, data.item3);
        return data.item2;
      });

      expect(doneCompleter.future, completes);
    }

    void expectContinued(ExecutionResult actual, dynamic multipass) =>
        actual.maybeWhen(
          orElse: () =>
              fail('Expected ExecutionResult.continued, but got $actual'),
          continued: (job) => expect(
            job,
            isA<UploadJob<int>>()
                .having((j) => j.key, 'key', key)
                .having((j) => j.syncNode, 'syncNode', same(mockSyncNode))
                .having((j) => j.multipass, 'multipass', multipass),
          ),
        );

    // ignore: avoid_positional_boolean_parameters
    UploadJob<int> createSut([bool multipass = false]) => UploadJob(
          syncNode: mockSyncNode,
          key: key,
          multipass: multipass,
        );

    setUp(() {
      reset(mockSyncNode);
      reset(mockSyncObjectStore);
      reset(mockCryptoFirebaseStore);
      reset(mockDataEncryptor);
      reset(mockJsonConverter);
      reset(mockConflictResolver);
      reset(mockTransaction);

      when(() => mockSyncNode.localStore).thenReturn(mockSyncObjectStore);
      when(() => mockSyncNode.remoteStore).thenReturn(mockCryptoFirebaseStore);
      when(() => mockSyncNode.dataEncryptor).thenReturn(mockDataEncryptor);
      when(() => mockSyncNode.jsonConverter).thenReturn(mockJsonConverter);
      when(() => mockSyncNode.conflictResolver)
          .thenReturn(mockConflictResolver);

      when(() => mockCryptoFirebaseStore.transaction(any()))
          .thenAnswer((i) async => mockTransaction);
      when(() => mockCryptoFirebaseStore.remoteUri(any())).thenReturn(uri);
      when<dynamic>(() => mockJsonConverter.dataToJson(any()))
          .thenReturn(jsonData);
      when<dynamic>(
        () => mockDataEncryptor.decrypt(
          remoteUri: any(named: 'remoteUri'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((i) async => jsonData);
      when(() => mockTransaction.commitUpdate(any()))
          .thenAnswer((i) async => null);
      when(() => mockTransaction.commitDelete()).thenAnswer((i) async {});
    });

    group('executeImpl', () {
      test('does nothing if not locally modified', () async {
        when(() => mockSyncObjectStore.get(any())).thenAnswer(
          (i) async => SyncObject.remote(
            10,
            Uint8List(SyncObject.remoteTagMin),
          ),
        );

        final result = await createSut().executeImpl();

        expect(result, const ExecutionResult.noop());

        verify(() => mockSyncObjectStore.get(key));
        verifyNever(() => mockCryptoFirebaseStore.transaction(any()));
      });

      test('uploads locally modified data', () async {
        final localData = SyncObject.local(10);
        final updatedCipher = FakeCipherMessage(
          Uint8List.fromList(
            List.generate(
              SyncObject.remoteTagMin,
              (index) => index + 3,
            ),
          ),
        );

        when(() => mockSyncObjectStore.get(any()))
            .thenAnswer((i) async => localData);
        whenTransact();
        whenEncrypt().thenAnswer((i) async => updatedCipher);
        whenUpdate(
          oldData: localData.copyWith(value: 99),
          newData: localData.copyWith(
            changeState: 0,
            remoteTag: updatedCipher.remoteTag,
          ),
          resultMatcher: UpdateAction.update(
            localData.copyWith(
              value: 99,
              changeState: 0,
              remoteTag: updatedCipher.remoteTag,
            ),
          ),
        );

        final result = await createSut().executeImpl();

        expect(result, const ExecutionResult.modified());

        verifyInOrder<dynamic>([
          () => mockSyncObjectStore.get(key),
          () => mockCryptoFirebaseStore.transaction(key),
          () => mockCryptoFirebaseStore.remoteUri(key),
          () => mockJsonConverter.dataToJson(localData.value!),
          () => mockDataEncryptor.encrypt(remoteUri: uri, dataJson: jsonData),
          () => mockTransaction.commitUpdate(updatedCipher),
          () => mockSyncObjectStore.update(key, any()),
        ]);
      });

      test('uploads locally modified data, overwrites cleared data', () async {
        final localData = SyncObject.local(10);
        final remoteTag = Uint8List(SyncObject.remoteTagMin);
        final remoteCipher = FakeCipherMessage(remoteTag);

        when(() => mockSyncObjectStore.get(any()))
            .thenAnswer((i) async => localData);
        whenTransact();
        whenEncrypt().thenAnswer((i) async => remoteCipher);
        whenUpdate(
          oldData: null,
          newData: localData.copyWith(
            changeState: 0,
            remoteTag: remoteTag,
          ),
          resultMatcher: UpdateAction.update(
            localData.copyWith(
              changeState: 0,
              remoteTag: remoteTag,
            ),
          ),
        );

        final result = await createSut().executeImpl();

        expect(result, const ExecutionResult.modified());

        verifyInOrder<dynamic>([
          () => mockSyncObjectStore.get(key),
          () => mockCryptoFirebaseStore.transaction(key),
          () => mockCryptoFirebaseStore.remoteUri(key),
          () => mockJsonConverter.dataToJson(localData.value!),
          () => mockDataEncryptor.encrypt(remoteUri: uri, dataJson: jsonData),
          () => mockTransaction.commitUpdate(remoteCipher),
          () => mockSyncObjectStore.update(key, any()),
        ]);
      });

      testData<bool>(
        'uploads locally modified data, reschedules if still modified',
        const [false, true],
        (fixture) async {
          final oldRemoteTag = Uint8List.fromList(
            List.filled(SyncObject.remoteTagMin, 9),
          );
          final newRemoteTag = Uint8List.fromList(
            List.filled(SyncObject.remoteTagMin, 10),
          );
          final localData = SyncObject(
            value: 15,
            changeState: 3,
            remoteTag: oldRemoteTag,
          );
          final remoteCipher = FakeCipherMessage(newRemoteTag);

          when(() => mockSyncObjectStore.get(any()))
              .thenAnswer((i) async => localData);
          whenTransact(oldRemoteTag);
          whenEncrypt().thenAnswer((i) async => remoteCipher);
          whenUpdate(
            oldData: localData.copyWith(changeState: 10),
            newData: localData.copyWith(remoteTag: newRemoteTag),
            resultMatcher: UpdateAction.update(
              localData.copyWith(
                changeState: 10,
                remoteTag: newRemoteTag,
              ),
            ),
          );

          final result = await createSut(fixture).executeImpl();

          if (fixture) {
            expectContinued(result, isTrue);
          } else {
            expect(result, const ExecutionResult.modified());
          }

          verifyInOrder<dynamic>([
            () => mockSyncObjectStore.get(key),
            () => mockCryptoFirebaseStore.transaction(key),
            () => mockCryptoFirebaseStore.remoteUri(key),
            () => mockJsonConverter.dataToJson(localData.value!),
            () => mockDataEncryptor.encrypt(remoteUri: uri, dataJson: jsonData),
            () => mockTransaction.commitUpdate(remoteCipher),
            () => mockSyncObjectStore.update(key, any()),
          ]);
        },
      );

      testData<bool>(
        'reschedules upload if transaction update commit fails',
        const [false, true],
        (fixture) async {
          final localData = SyncObject.local(10);
          final remoteCipher = FakeCipherMessage();

          when(() => mockSyncObjectStore.get(any()))
              .thenAnswer((i) async => localData);
          whenTransact();
          when(() => mockTransaction.commitUpdate(any())).thenAnswer(
            (i) async => throw const TransactionFailedException(),
          );
          whenEncrypt().thenAnswer((i) async => remoteCipher);

          final result = await createSut(fixture).executeImpl();

          expectContinued(result, fixture);

          verifyInOrder<dynamic>([
            () => mockSyncObjectStore.get(key),
            () => mockCryptoFirebaseStore.transaction(key),
            () => mockCryptoFirebaseStore.remoteUri(key),
            () => mockJsonConverter.dataToJson(localData.value!),
            () => mockDataEncryptor.encrypt(remoteUri: uri, dataJson: jsonData),
            () => mockTransaction.commitUpdate(remoteCipher),
          ]);
          verifyNever(() => mockSyncObjectStore.update(any(), any()));
        },
      );

      test('uploads locally deleted data', () async {
        final remoteTag = Uint8List.fromList(
          List.filled(SyncObject.remoteTagMin, 5),
        );
        final localData = SyncObject<int>(
          value: null,
          changeState: 1,
          remoteTag: remoteTag,
        );

        when(() => mockSyncObjectStore.get(any()))
            .thenAnswer((i) async => localData);
        whenTransact(remoteTag);
        whenUpdate(
          oldData: localData,
          newData: null,
          resultMatcher: const UpdateAction.delete(),
        );

        final result = await createSut().executeImpl();

        expect(result, const ExecutionResult.modified());

        verifyInOrder<dynamic>([
          () => mockSyncObjectStore.get(key),
          () => mockCryptoFirebaseStore.transaction(key),
          () => mockTransaction.commitDelete(),
          () => mockSyncObjectStore.update(key, any()),
        ]);
      });

      test('uploads locally deleted data, ignores cleared data', () async {
        final remoteTag = Uint8List.fromList(
          List.filled(SyncObject.remoteTagMin, 5),
        );
        final localData = SyncObject<int>(
          value: null,
          changeState: 1,
          remoteTag: remoteTag,
        );

        when(() => mockSyncObjectStore.get(any()))
            .thenAnswer((i) async => localData);
        whenTransact(remoteTag);
        whenUpdate(
          oldData: null,
          newData: null,
          resultMatcher: const UpdateAction.none(),
        );

        final result = await createSut().executeImpl();

        expect(result, const ExecutionResult.modified());

        verifyInOrder<dynamic>([
          () => mockSyncObjectStore.get(key),
          () => mockCryptoFirebaseStore.transaction(key),
          () => mockTransaction.commitDelete(),
          () => mockSyncObjectStore.update(key, any()),
        ]);
      });

      testData<bool>(
        'uploads locally deleted data, reschedules if modified',
        const [false, true],
        (fixture) async {
          final remoteTag = Uint8List.fromList(
            List.filled(SyncObject.remoteTagMin, 9),
          );
          final localData = SyncObject<int>(
            value: null,
            changeState: 1,
            remoteTag: remoteTag,
          );

          when(() => mockSyncObjectStore.get(any()))
              .thenAnswer((i) async => localData);
          whenTransact(remoteTag);
          whenUpdate(
            oldData: localData.copyWith(
              value: 77,
              changeState: 12,
            ),
            newData: localData.copyWith(
              value: 77,
              changeState: 12,
              remoteTag: SyncObject.noRemoteDataTag,
            ),
            resultMatcher: UpdateAction.update(
              localData.copyWith(
                value: 77,
                changeState: 12,
                remoteTag: SyncObject.noRemoteDataTag,
              ),
            ),
          );

          final result = await createSut(fixture).executeImpl();

          if (fixture) {
            expectContinued(result, isTrue);
          } else {
            expect(result, const ExecutionResult.modified());
          }

          verifyInOrder<dynamic>([
            () => mockSyncObjectStore.get(key),
            () => mockCryptoFirebaseStore.transaction(key),
            () => mockTransaction.commitDelete(),
            () => mockSyncObjectStore.update(key, any()),
          ]);
        },
      );

      testData<bool>(
        'reschedules upload if transaction delete commit fails',
        const [false, true],
        (fixture) async {
          final remoteTag = Uint8List.fromList(
            List.filled(SyncObject.remoteTagMin, 9),
          );
          final localData = SyncObject<int>(
            value: null,
            changeState: 1,
            remoteTag: remoteTag,
          );

          when(() => mockSyncObjectStore.get(any()))
              .thenAnswer((i) async => localData);
          whenTransact(remoteTag);
          when(() => mockTransaction.commitDelete()).thenAnswer(
            (i) async => throw const TransactionFailedException(),
          );

          final result = await createSut(fixture).executeImpl();

          expectContinued(result, fixture);

          verifyInOrder<dynamic>([
            () => mockSyncObjectStore.get(key),
            () => mockCryptoFirebaseStore.transaction(key),
            () => mockTransaction.commitDelete(),
          ]);
          verifyNever(() => mockSyncObjectStore.update(any(), any()));
        },
      );
    });

    group('resolves conflicts', () {
      test('with resolution remote and does not upload anymore', () async {
        final localData = SyncObject.local(9);
        const remoteData = 18;
        final remoteTag = Uint8List.fromList(
          List.filled(SyncObject.remoteTagMin, 16),
        );
        final remoteCipher = FakeCipherMessage(remoteTag);

        when(() => mockSyncObjectStore.get(any()))
            .thenAnswer((i) async => localData);
        when(() => mockTransaction.value).thenReturn(remoteCipher);
        when(() => mockJsonConverter.dataFromJson(any<dynamic>()))
            .thenReturn(remoteData);
        when(
          () => mockConflictResolver.resolve(
            any(),
            local: any(named: 'local'),
            remote: any(named: 'remote'),
          ),
        ).thenReturn(const ConflictResolution.remote());
        whenUpdate(
          oldData: localData,
          newData: localData.copyWith(
            value: remoteData,
            changeState: 0,
            remoteTag: remoteTag,
          ),
          resultMatcher: UpdateAction.update(
            localData.copyWith(
              value: remoteData,
              changeState: 0,
              remoteTag: remoteTag,
            ),
          ),
        );

        final result = await createSut().executeImpl();
        expect(result, const ExecutionResult.modified());

        verifyInOrder<dynamic>([
          () => mockSyncObjectStore.get(key),
          () => mockCryptoFirebaseStore.transaction(key),
          () => mockCryptoFirebaseStore.remoteUri(key),
          () => mockDataEncryptor.decrypt(remoteUri: uri, data: remoteCipher),
          () => mockJsonConverter.dataFromJson(jsonData),
          () => mockSyncObjectStore.update(key, any()),
          () => mockConflictResolver.resolve(
                key,
                local: localData.value,
                remote: remoteData,
              ),
        ]);
        verifyNever(() => mockTransaction.commitUpdate(any()));
      });

      test('with resolution local and uploads new data', () async {
        final localData = SyncObject(
          value: 9,
          changeState: 1,
          remoteTag: Uint8List(SyncObject.remoteTagMin),
        );
        final resolvedData = localData.copyWith(
          remoteTag: SyncObject.noRemoteDataTag,
        );
        final resolvedCipherMessage = FakeCipherMessage();

        when(() => mockSyncObjectStore.get(any()))
            .thenAnswer((i) async => localData);
        when(() => mockTransaction.value).thenReturn(null);
        when(
          () => mockConflictResolver.resolve(
            any(),
            local: any(named: 'local'),
            remote: any(named: 'remote'),
          ),
        ).thenReturn(const ConflictResolution.local());
        whenUpdateMany([
          Tuple3<SyncObject<int>?, SyncObject<int>?, dynamic>(
            localData,
            resolvedData,
            UpdateAction.update(resolvedData),
          ),
          Tuple3<SyncObject<int>?, SyncObject<int>?, dynamic>(
            resolvedData,
            resolvedData.copyWith(changeState: 0),
            UpdateAction.update(resolvedData.copyWith(changeState: 0)),
          ),
        ]);
        whenEncrypt().thenAnswer((i) async => resolvedCipherMessage);

        final result = await createSut().executeImpl();
        expect(result, const ExecutionResult.modified());

        verifyInOrder<dynamic>([
          () => mockSyncObjectStore.get(key),
          () => mockCryptoFirebaseStore.transaction(key),
          () => mockSyncObjectStore.update(key, any()),
          () => mockConflictResolver.resolve(
                key,
                local: localData.value,
                remote: null,
              ),
          () => mockCryptoFirebaseStore.remoteUri(key),
          () => mockJsonConverter.dataToJson(resolvedData.value!),
          () => mockDataEncryptor.encrypt(remoteUri: uri, dataJson: jsonData),
          () => mockTransaction.commitUpdate(resolvedCipherMessage),
          () => mockSyncObjectStore.update(key, any()),
        ]);
        verifyNever(
          () => mockDataEncryptor.decrypt(
            remoteUri: any(named: 'remoteUri'),
            data: any(named: 'data'),
          ),
        );
      });
    });
  });
}
