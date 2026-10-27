import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionInfo', () {
    test('compares version first', () {
      expect(
        VersionInfo.parse('2.5.0', build: 1) <
            VersionInfo.parse('2.6.0', build: 0),
        isTrue,
      );
    });

    test('uses build as a tie-breaker when both are known', () {
      expect(
        VersionInfo.parse('2.5.0', build: 250) <
            VersionInfo.parse('2.5.0', build: 251),
        isTrue,
      );
      expect(
        VersionInfo.parse('2.5.0', build: 251) >=
            VersionInfo.parse('2.5.0', build: 250),
        isTrue,
      );
    });

    test('ignores build when either side lacks one', () {
      expect(
        VersionInfo.parse('2.5.0')
            .compareTo(VersionInfo.parse('2.5.0', build: 9)),
        0,
      );
    });

    test('parses from json with int or string builds', () {
      expect(
        VersionInfo.fromJson({'version': '1.2.3', 'build': 12})!.build,
        12,
      );
      expect(
        VersionInfo.fromJson({'version': '1.2.3', 'build': '12'})!.build,
        12,
      );
      expect(VersionInfo.fromJson({'version': '1.2.3'})!.build, isNull);
      expect(VersionInfo.fromJson({'version': 'nope'}), isNull);
      expect(VersionInfo.fromJson(null), isNull);
    });

    test('round-trips through json', () {
      final info = VersionInfo.parse('2.7.0', build: 270);
      expect(VersionInfo.fromJson(info.toJson()), info);
    });
  });
}
