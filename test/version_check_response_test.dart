import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sampleBody({
  Map<String, dynamic>? minimum,
  Map<String, dynamic>? policy,
  int schema = 1,
}) =>
    {
      'schema_version': schema,
      'app': {
        'id': 'com.example.app',
        'platform': 'android',
        'channel': 'production',
      },
      'latest': {'version': '2.7.0', 'build': 270},
      if (minimum != null) 'minimum': minimum,
      'recommended': {'version': '2.7.0', 'build': 270},
      'policy': policy ??
          {
            'mode': 'custom',
            'force_update': true,
            'update_message': 'Please update to continue.',
          },
      'update': {
        'url': 'https://play.google.com/store/apps/details?id=com.example.app',
        'release_notes': 'Bug fixes.',
      },
      'server_time': '2026-10-27T05:30:00Z',
    };

void main() {
  group('VersionCheckResponse.fromJson', () {
    test('parses the documented payload', () {
      final r = VersionCheckResponse.fromJson(
        sampleBody(minimum: {'version': '2.5.0', 'build': 250}),
      );
      expect(r.appId, 'com.example.app');
      expect(r.platform, 'android');
      expect(r.channel, VersionChannel.production);
      expect(r.latest, VersionInfo.parse('2.7.0', build: 270));
      expect(r.minimum, VersionInfo.parse('2.5.0', build: 250));
      expect(r.recommended, VersionInfo.parse('2.7.0', build: 270));
      expect(r.policy.mode, PolicyMode.custom);
      expect(r.policy.forceUpdate, isTrue);
      expect(r.policy.enabled, isTrue);
      expect(r.policy.updateMessage, 'Please update to continue.');
      expect(r.updateUrl, contains('play.google.com'));
      expect(r.releaseNotes, 'Bug fixes.');
      expect(r.serverTime, DateTime.utc(2026, 10, 27, 5, 30));
    });

    test('defaults minimum to latest when omitted (AUTO_LATEST)', () {
      final r = VersionCheckResponse.fromJson(sampleBody());
      expect(r.minimum, r.latest);
    });

    test('maps unknown policy modes to PolicyMode.unknown', () {
      final r = VersionCheckResponse.fromJson(
        sampleBody(policy: {'mode': 'something_new', 'force_update': 'true'}),
      );
      expect(r.policy.mode, PolicyMode.unknown);
      expect(r.policy.forceUpdate, isTrue);
    });

    test('rejects a missing latest', () {
      final body = sampleBody()..remove('latest');
      expect(
        () => VersionCheckResponse.fromJson(body),
        throwsA(isA<VersionResponseException>()),
      );
    });

    test('rejects a newer schema version', () {
      expect(
        () => VersionCheckResponse.fromJson(sampleBody(schema: 2)),
        throwsA(isA<VersionResponseException>()),
      );
    });

    test('round-trips through toJson', () {
      final original = VersionCheckResponse.fromJson(
        sampleBody(minimum: {'version': '2.5.0', 'build': 250}),
      );
      final copy = VersionCheckResponse.fromJson(original.toJson());
      expect(copy.latest, original.latest);
      expect(copy.minimum, original.minimum);
      expect(copy.recommended, original.recommended);
      expect(copy.policy, original.policy);
      expect(copy.updateUrl, original.updateUrl);
      expect(copy.releaseNotes, original.releaseNotes);
      expect(copy.serverTime, original.serverTime);
      expect(copy.channel, original.channel);
    });
  });

  group('CachedPolicy', () {
    test('round-trips and reports expiry', () {
      final response = VersionCheckResponse.fromJson(sampleBody());
      final cached = CachedPolicy(
        response: response,
        receivedAt: DateTime.utc(2026, 10, 27, 5),
        expiresAt: DateTime.utc(2026, 10, 28, 5),
      );
      final copy = CachedPolicy.fromJson(cached.toJson())!;
      expect(copy.receivedAt, cached.receivedAt);
      expect(copy.expiresAt, cached.expiresAt);
      expect(copy.response.latest, response.latest);
      expect(copy.isExpiredAt(DateTime.utc(2026, 10, 27, 12)), isFalse);
      expect(copy.isExpiredAt(DateTime.utc(2026, 10, 28, 5)), isTrue);
    });

    test('returns null for a corrupt envelope', () {
      expect(CachedPolicy.fromJson({'response': 'x'}), isNull);
      expect(CachedPolicy.fromJson({}), isNull);
    });
  });
}
