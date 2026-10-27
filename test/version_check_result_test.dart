import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';

VersionCheckResponse response({
  required String latest,
  required String minimum,
  String? recommended,
  bool forceUpdate = true,
  bool enabled = true,
}) => VersionCheckResponse(
  schemaVersion: 1,
  appId: 'com.example.app',
  platform: 'android',
  channel: VersionChannel.production,
  latest: VersionInfo.parse(latest),
  minimum: VersionInfo.parse(minimum),
  recommended: recommended == null ? null : VersionInfo.parse(recommended),
  policy: VersionPolicy(
    mode: PolicyMode.custom,
    forceUpdate: forceUpdate,
    enabled: enabled,
    updateMessage: 'Update please',
  ),
  updateUrl: 'https://example.com/update',
);

VersionCheckResult evaluate(String current, VersionCheckResponse r) =>
    VersionCheckResult.evaluate(
      current: VersionInfo.parse(current),
      response: r,
      source: CheckSource.network,
      checkedAt: DateTime.utc(2026),
    );

void main() {
  group('VersionCheckResult.evaluate', () {
    final custom = response(latest: '2.7.0', minimum: '2.5.0');

    test('CUSTOM policy: below minimum is required', () {
      final r = evaluate('2.4.9', custom);
      expect(r.status, UpdateStatus.updateRequired);
      expect(r.isUpdateRequired, isTrue);
      expect(r.isUpdateAvailable, isTrue);
      expect(r.isBelowMinimum, isTrue);
      expect(r.isBlocked, isTrue);
      expect(r.updateMessage, 'Update please');
      expect(r.updateUrl, 'https://example.com/update');
    });

    test('CUSTOM policy: between minimum and latest is available', () {
      for (final v in ['2.5.0', '2.6.0']) {
        final r = evaluate(v, custom);
        expect(r.status, UpdateStatus.updateAvailable, reason: v);
        expect(r.isBlocked, isFalse);
        expect(r.isBelowMinimum, isFalse);
      }
    });

    test('CUSTOM policy: at or above latest is up to date', () {
      expect(evaluate('2.7.0', custom).status, UpdateStatus.upToDate);
      expect(evaluate('2.8.0', custom).status, UpdateStatus.upToDate);
    });

    test('AUTO_LATEST policy: anything below latest is required', () {
      final auto = response(latest: '2.7.0', minimum: '2.7.0');
      expect(evaluate('2.6.9', auto).status, UpdateStatus.updateRequired);
      expect(evaluate('2.7.0', auto).status, UpdateStatus.upToDate);
    });

    test('force_update=false never blocks', () {
      final soft = response(
        latest: '2.7.0',
        minimum: '2.5.0',
        forceUpdate: false,
      );
      final r = evaluate('2.4.0', soft);
      expect(r.status, UpdateStatus.updateAvailable);
      expect(r.isBelowMinimum, isTrue);
      expect(r.isBlocked, isFalse);
    });

    test('disabled policy never blocks', () {
      final off = response(latest: '2.7.0', minimum: '2.7.0', enabled: false);
      expect(evaluate('1.0.0', off).status, UpdateStatus.updateAvailable);
    });

    test('recommended is surfaced separately', () {
      final r = evaluate(
        '2.5.0',
        response(latest: '2.7.0', minimum: '2.5.0', recommended: '2.6.0'),
      );
      expect(r.isBelowRecommended, isTrue);
      expect(r.status, UpdateStatus.updateAvailable);
    });

    test('builds break version ties', () {
      final r = VersionCheckResult.evaluate(
        current: VersionInfo.parse('2.7.0', build: 269),
        response: VersionCheckResponse(
          schemaVersion: 1,
          appId: 'a',
          platform: 'android',
          channel: VersionChannel.production,
          latest: VersionInfo.parse('2.7.0', build: 270),
          minimum: VersionInfo.parse('2.7.0', build: 270),
          policy: const VersionPolicy(
            mode: PolicyMode.autoLatest,
            forceUpdate: true,
          ),
        ),
        source: CheckSource.network,
        checkedAt: DateTime.utc(2026),
      );
      expect(r.status, UpdateStatus.updateRequired);
    });
  });

  group('VersionCheckResult.failed', () {
    test('fail-open does not block', () {
      final r = VersionCheckResult.failed(
        current: VersionInfo.parse('1.0.0'),
        checkedAt: DateTime.utc(2026),
        blockWhenUnknown: false,
      );
      expect(r.status, UpdateStatus.checkFailed);
      expect(r.isFailed, isTrue);
      expect(r.isBlocked, isFalse);
      expect(r.isUpdateAvailable, isFalse);
    });

    test('fail-closed blocks', () {
      final r = VersionCheckResult.failed(
        current: VersionInfo.parse('1.0.0'),
        checkedAt: DateTime.utc(2026),
        blockWhenUnknown: true,
      );
      expect(r.isBlocked, isTrue);
    });

    test('toJson includes the decision flags', () {
      final json = evaluate(
        '2.4.0',
        response(latest: '2.7.0', minimum: '2.5.0'),
      ).toJson();
      expect(json['status'], 'updateRequired');
      expect(json['is_blocked'], isTrue);
      expect(json['latest'], {'version': '2.7.0'});
    });
  });
}
