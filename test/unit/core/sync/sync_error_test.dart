import 'package:firebase_sync/src/core/sync/sync_error.dart';
import 'package:test/test.dart';

void main() {
  group('SyncError', () {
    group('named', () {
      test('adds name to unnamed error', () {
        const name = 'test';
        final sut = SyncError(42, StackTrace.current);

        final named = sut.named(name);
        expect(named.name, name);
        expect(named.error, same(sut.error));
        expect(named.stackTrace, same(sut.stackTrace));
      });

      test('throws if trying to add a name to an already named error', () {
        const sut = NamedSyncError(name: 'name', error: true);
        expect(() => sut.named('error'), throwsA(isA<UnsupportedError>()));
      });
    });
  });
}
