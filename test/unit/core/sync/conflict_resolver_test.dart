import 'package:firebase_sync/src/core/sync/conflict_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('_DefaultConflictResolver', () {
    late ConflictResolver<String> sut;

    setUp(() {
      sut = const ConflictResolver();
    });

    test('always resolves with ConflictResolution.remote', () {
      final resolution = sut.resolve('key', local: 'local', remote: 'remote');
      expect(
        resolution.maybeWhen(
          remote: () => true,
          orElse: () => false,
        ),
        isTrue,
      );
    });
  });
}
