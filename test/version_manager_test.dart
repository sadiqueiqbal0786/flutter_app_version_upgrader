import 'dart:convert';

import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_platform.dart';
import 'version_check_response_test.dart' show sampleBody;

void main() {
  late FakePlatform platform;
  final t0 = DateTime.utc(2026, 10, 27, 5);
  DateTime now = t0;

  const baseConfig = VersionManagerConfig(
    baseUrl: 'https://versions.example.com',
    cacheTtl: Duration(hours: 24),
  );

  setUp(() {
    platform = FakePlatform();
    now = t0;
  });

  VersionManager manager({
    VersionManagerConfig config = baseConfig,
    required MockClientHandler handler,
  }) => VersionManager(
    config,
    platform: platform,
    httpClient: MockClient(handler),
    clock: () => now,
  );

  MockClientHandler ok(Map<String, dynamic> body) =>
      (_) async => http.Response(jsonEncode(body), 200);

  MockClientHandler down() =>
      (_) async => http.Response('', 503);

  final customBody = sampleBody(minimum: {'version': '2.5.0', 'build': 250});

  group('VersionManager.checkVersion', () {
    test('network success evaluates and caches', () async {
      var calls = 0;
      final m = manager(
        handler: (r) async {
          calls++;
          return http.Response(jsonEncode(customBody), 200);
        },
      );

      final result = await m.checkVersion();

      expect(result.status, UpdateStatus.updateRequired);
      expect(result.source, CheckSource.network);
      expect(result.current, VersionInfo.parse('2.4.1', build: 241));
      expect(result.latest, VersionInfo.parse('2.7.0', build: 270));
      expect(result.minimum, VersionInfo.parse('2.5.0', build: 250));
      expect(calls, 1);
      expect(
        platform.store.keys.single,
        'flutter_app_version_upgrader.policy.com.example.app.android.production',
      );
      expect(m.lastResult, same(result));
    });

    test('cache key includes the channel', () async {
      final m = manager(
        config: baseConfig.copyWith(channel: VersionChannel.beta),
        handler: ok(customBody),
      );
      await m.checkVersion();
      expect(platform.store.keys.single, endsWith('.beta'));
    });

    test('API outage falls back to a fresh cache', () async {
      await manager(handler: ok(customBody)).checkVersion();

      now = t0.add(const Duration(hours: 1));
      final result = await manager(handler: down()).checkVersion();

      expect(result.status, UpdateStatus.updateRequired);
      expect(result.source, CheckSource.cache);
      expect(result.isStale, isFalse);
    });

    test(
      'API outage falls back to an expired cache and marks it stale',
      () async {
        await manager(handler: ok(customBody)).checkVersion();

        now = t0.add(const Duration(hours: 25));
        final result = await manager(handler: down()).checkVersion();

        expect(result.source, CheckSource.cache);
        expect(result.isStale, isTrue);
        expect(result.status, UpdateStatus.updateRequired);
      },
    );

    test('expired cache is ignored when stale use is disabled', () async {
      await manager(handler: ok(customBody)).checkVersion();

      now = t0.add(const Duration(hours: 25));
      final result = await manager(
        config: baseConfig.copyWith(allowStaleCache: false),
        handler: down(),
      ).checkVersion();

      expect(result.status, UpdateStatus.checkFailed);
    });

    test('no API and no cache fails open by default', () async {
      final result = await manager(handler: down()).checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.source, CheckSource.none);
      expect(result.isBlocked, isFalse);
      expect(result.error, isA<VersionApiException>());
    });

    test('no API and no cache fails closed when configured', () async {
      final result = await manager(
        config: baseConfig.copyWith(failurePolicy: FailurePolicy.closed),
        handler: down(),
      ).checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.isBlocked, isTrue);
    });

    test('corrupt cache behaves like no cache', () async {
      platform.store['flutter_app_version_upgrader.policy.com.example.app.android.production'] =
          '{not json';
      final result = await manager(handler: down()).checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
    });

    test('an unusable response falls back to cache', () async {
      await manager(handler: ok(customBody)).checkVersion();
      final result = await manager(handler: ok({'schema_version': 99}))
          .checkVersion();
      expect(result.source, CheckSource.cache);
    });

    test('preferCache skips the network while the cache is fresh', () async {
      await manager(handler: ok(customBody)).checkVersion();

      var calls = 0;
      final m = manager(
        handler: (_) async {
          calls++;
          return http.Response(jsonEncode(customBody), 200);
        },
      );
      final cached = await m.checkVersion(preferCache: true);
      expect(cached.source, CheckSource.cache);
      expect(calls, 0);

      now = t0.add(const Duration(hours: 25));
      final fresh = await m.checkVersion(preferCache: true);
      expect(fresh.source, CheckSource.network);
      expect(calls, 1);
    });

    test('concurrent checks share one request', () async {
      var calls = 0;
      final m = manager(
        handler: (_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(jsonEncode(customBody), 200);
        },
      );
      final results = await Future.wait([m.checkVersion(), m.checkVersion()]);
      expect(calls, 1);
      expect(results[0], same(results[1]));
    });

    test('cache write failures do not fail the check', () async {
      platform.failCacheWrites = true;
      final result = await manager(handler: ok(customBody)).checkVersion();
      expect(result.source, CheckSource.network);
    });

    test('cache read failures do not fail the check', () async {
      platform.failCacheReads = true;
      final result = await manager(handler: down()).checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
    });

    test('unreadable app info yields checkFailed', () async {
      platform.failAppInfo = true;
      final result = await manager(handler: ok(customBody)).checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.error, isA<StateError>());
    });

    test('unparsable installed version yields checkFailed', () async {
      platform.appInfo = const AppInfo(
        packageName: 'com.example.app',
        versionName: 'weird',
        buildNumber: 1,
        platform: 'android',
      );
      final result = await manager(handler: ok(customBody)).checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.error, isA<VersionFormatException>());
    });

    test('currentVersionOverride replaces the installed version', () async {
      final result = await manager(
        config: baseConfig.copyWith(
          currentVersionOverride: VersionInfo.parse('2.7.0', build: 270),
        ),
        handler: ok(customBody),
      ).checkVersion();
      expect(result.status, UpdateStatus.upToDate);
    });

    test('appId override is sent and used for the cache key', () async {
      http.Request? seen;
      final m = manager(
        config: baseConfig.copyWith(appId: 'custom-id'),
        handler: (r) async {
          seen = r;
          return http.Response(jsonEncode(customBody), 200);
        },
      );
      await m.checkVersion();
      expect(seen!.url.queryParameters['app_id'], 'custom-id');
      expect(platform.store.keys.single, contains('.custom-id.'));
    });

    test('results stream emits every result', () async {
      final m = manager(handler: ok(customBody));
      final emitted = <VersionCheckResult>[];
      final sub = m.results.listen(emitted.add);
      await m.checkVersion();
      await m.checkVersion();
      await Future<void>.delayed(Duration.zero);
      expect(emitted, hasLength(2));
      await sub.cancel();
    });

    test('logger receives fallback messages', () async {
      final logs = <String>[];
      await manager(
        config: baseConfig.copyWith(logger: (m, [e]) => logs.add(m)),
        handler: down(),
      ).checkVersion();
      expect(logs, contains(contains('falling back to cache')));
    });
  });

  group('VersionManager store and cache helpers', () {
    test('openStoreFor prefers the backend URL', () async {
      final m = manager(handler: ok(customBody));
      final result = await m.checkVersion();
      await m.openStoreFor(result);
      expect(platform.opened.single, contains('play.google.com'));
    });

    test('openStoreFor falls back to the package listing', () async {
      final m = manager(
        config: baseConfig.copyWith(appStoreId: '123'),
        handler: ok(customBody),
      );
      await m.openStoreFor();
      expect(platform.opened.single, 'store:com.example.app:123');
    });

    test('clearCachedPolicy removes the entry', () async {
      final m = manager(handler: ok(customBody));
      await m.checkVersion();
      expect(platform.store, isNotEmpty);
      await m.clearCachedPolicy();
      expect(platform.store, isEmpty);
    });
  });

  group('VersionManager static API', () {
    tearDown(VersionManager.reset);

    test('throws before initialize', () {
      expect(() => VersionManager.instance, throwsStateError);
      expect(VersionManager.isInitialized, isFalse);
    });

    test('initialize + check work end to end', () async {
      FlutterAppVersionUpgraderPlatform.instance = platform;
      await VersionManager.initialize(
        baseConfig,
        httpClient: MockClient(ok(customBody)),
      );
      expect(VersionManager.isInitialized, isTrue);
      final result = await VersionManager.check();
      expect(result.status, UpdateStatus.updateRequired);
      await VersionManager.openStore(result);
      expect(platform.opened, hasLength(1));
      await VersionManager.clearCache();
      expect(platform.store, isEmpty);
    });
  });
}
