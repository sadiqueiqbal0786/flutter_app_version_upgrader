import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SemanticVersion.parse', () {
    test('parses full versions', () {
      final v = SemanticVersion.parse('2.7.0');
      expect(v.major, 2);
      expect(v.minor, 7);
      expect(v.patch, 0);
      expect(v.isPreRelease, isFalse);
    });

    test('fills missing minor and patch', () {
      expect(SemanticVersion.parse('2.7'), SemanticVersion.parse('2.7.0'));
      expect(SemanticVersion.parse('3'), SemanticVersion.parse('3.0.0'));
    });

    test('accepts a leading v and whitespace', () {
      expect(SemanticVersion.parse(' v1.2.3 '), const SemanticVersion(1, 2, 3));
    });

    test('parses pre-release and build metadata', () {
      final v = SemanticVersion.parse('2.8.0-beta.2+45');
      expect(v.preRelease, ['beta', '2']);
      expect(v.build, ['45']);
      expect(v.toString(), '2.8.0-beta.2+45');
    });

    test('rejects garbage', () {
      for (final bad in ['', 'abc', '1.2.3.4', '1..2', '1.2.3-', '1.2.3+', '-1']) {
        expect(SemanticVersion.tryParse(bad), isNull, reason: bad);
      }
      expect(() => SemanticVersion.parse('x'),
          throwsA(isA<VersionFormatException>()));
    });
  });

  group('SemanticVersion ordering', () {
    SemanticVersion v(String s) => SemanticVersion.parse(s);

    test('compares numerically, not lexically', () {
      expect(v('2.10.0') > v('2.9.0'), isTrue);
      expect(v('10.0.0') > v('9.9.9'), isTrue);
      expect('2.10.0'.compareTo('2.9.0') < 0, isTrue,
          reason: 'string comparison is wrong, which is why we parse');
    });

    test('pre-release is lower than the release', () {
      expect(v('2.8.0-beta.2') < v('2.8.0'), isTrue);
      expect(v('2.8.0-beta.2') > v('2.7.9'), isTrue);
    });

    test('pre-release identifiers follow semver precedence', () {
      final ordered = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
      ];
      for (var i = 0; i < ordered.length - 1; i++) {
        expect(v(ordered[i]) < v(ordered[i + 1]), isTrue,
            reason: '${ordered[i]} < ${ordered[i + 1]}');
      }
    });

    test('build metadata is ignored', () {
      expect(v('1.0.0+1') == v('1.0.0+2'), isTrue);
      expect(v('1.0.0+1').compareTo(v('1.0.0')), 0);
    });

    test('core strips tags', () {
      expect(v('1.2.3-rc.1+7').core, const SemanticVersion(1, 2, 3));
    });
  });
}
