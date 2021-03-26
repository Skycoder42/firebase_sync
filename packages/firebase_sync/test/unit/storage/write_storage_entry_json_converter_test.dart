import 'package:firebase_database_rest/firebase_database_rest.dart';
import 'package:firebase_sync/firebase_sync.dart';
import 'package:firebase_sync/src/storage/write_storage_entry_json_converter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockJsonConverter extends Mock implements JsonConverter<int> {}

void main() {
  final mockJsonConverter = MockJsonConverter();

  late WriteStorageEntryJsonConverter<int> sut;

  setUp(() {
    reset(mockJsonConverter);

    sut = WriteStorageEntryJsonConverter(mockJsonConverter);
  });

  test('correctly converts data from json', () {
    when(() => mockJsonConverter.dataFromJson(any<dynamic>())).thenReturn(10);

    final res = sut.dataFromJson(const <String, dynamic>{
      'value': 20,
      'eTag': 'TAG',
      'localModifications': 5,
    });

    expect(res.value, 10);
    expect(res.eTag, 'TAG');
    expect(res.localModifications, 5);

    verify(() => mockJsonConverter.dataFromJson(20));
  });

  test('correctly converts data from json with null value', () {
    when(() => mockJsonConverter.dataFromJson(any<dynamic>())).thenReturn(10);

    final res = sut.dataFromJson(const <String, dynamic>{
      'value': null,
      'eTag': 'TAG',
      'localModifications': 5,
    });

    expect(res.value, isNull);
    expect(res.eTag, 'TAG');
    expect(res.localModifications, 5);

    verifyNever(() => mockJsonConverter.dataFromJson(any<dynamic>()));
  });

  test('correctly converts data to json', () {
    when<dynamic>(() => mockJsonConverter.dataToJson(any())).thenReturn(10);

    final dynamic res = sut.dataToJson(const WriteStorageEntry(
      value: 20,
      eTag: 'TAG',
      localModifications: 5,
    ));

    expect(res, const <String, dynamic>{
      'value': 10,
      'eTag': 'TAG',
      'localModifications': 5,
    });

    verify<dynamic>(() => mockJsonConverter.dataToJson(20));
  });

  test('correctly converts data to json with null value', () {
    when<dynamic>(() => mockJsonConverter.dataToJson(any())).thenReturn(10);

    final dynamic res = sut.dataToJson(const WriteStorageEntry(
      value: null,
      eTag: 'TAG',
      localModifications: 5,
    ));

    expect(res, const <String, dynamic>{
      'value': null,
      'eTag': 'TAG',
      'localModifications': 5,
    });

    verifyNever<dynamic>(() => mockJsonConverter.dataToJson(any()));
  });

  test('patchData forwards patch to value', () {
    when(() => mockJsonConverter.patchData(any(), any())).thenReturn(10);

    const data = WriteStorageEntry(
      value: 20,
      eTag: 'TAG',
      localModifications: 5,
    );
    const patchSet = <String, dynamic>{'value': 30};
    final res = sut.patchData(data, patchSet);

    expect(res.value, 10);
    expect(res.eTag, data.eTag);
    expect(res.localModifications, data.localModifications);

    verify(() => mockJsonConverter.patchData(20, patchSet));
  });
}
