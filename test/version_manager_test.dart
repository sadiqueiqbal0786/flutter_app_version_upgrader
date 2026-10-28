import 'dart:convert';

import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_platform.dart';
import 'version_check_response_test.dart' show sampleBody;

void main() {
  _sourceTests();
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

void _sourceTests() {
  group('Bring your own source', () {
    late FakePlatform platform;
    setUp(() => platform = FakePlatform());

    test('a custom VersionSource replaces HTTP entirely', () async {
      VersionCheckRequest? seen;
      final m = VersionManager(
        const VersionManagerConfig(baseUrl: 'unused://'),
        platform: platform,
        source: VersionSource.fromCallback((request) async {
          seen = request;
          return VersionCheckResponse(
            schemaVersion: 1,
            appId: request.appId,
            platform: request.platform,
            channel: request.channel,
            latest: VersionInfo.parse('9.0.0'),
            minimum: VersionInfo.parse('9.0.0'),
            policy: const VersionPolicy(
              mode: PolicyMode.custom,
              forceUpdate: true,
            ),
            updateUrl: 'https://example.com/get',
          );
        }),
      );
      final result = await m.checkVersion();
      expect(seen!.appId, 'com.example.app');
      expect(seen!.current, VersionInfo.parse('2.4.1', build: 241));
      expect(result.status, UpdateStatus.updateRequired);
      expect(result.updateUrl, 'https://example.com/get');
      expect(result.source, CheckSource.network);
    });

    test(
      'a failing custom source falls back to cache and fails open',
      () async {
        final ok = VersionManager(
          const VersionManagerConfig(baseUrl: 'unused://'),
          platform: platform,
          source: VersionSource.fromCallback(
            (r) async => VersionCheckResponse(
              schemaVersion: 1,
              appId: r.appId,
              platform: r.platform,
              channel: r.channel,
              latest: VersionInfo.parse('3.0.0'),
              minimum: VersionInfo.parse('1.0.0'),
              policy: const VersionPolicy(
                mode: PolicyMode.custom,
                forceUpdate: true,
              ),
            ),
          ),
        );
        await ok.checkVersion();
        final broken = VersionManager(
          const VersionManagerConfig(baseUrl: 'unused://'),
          platform: platform,
          source: VersionSource.fromCallback(
            (_) async => throw StateError('boom'),
          ),
        );
        final cached = await broken.checkVersion();
        expect(cached.source, CheckSource.cache);
        expect(cached.status, UpdateStatus.updateAvailable);
      },
    );

    test('responseParser maps a foreign JSON shape', () async {
      final m = VersionManager(
        VersionManagerConfig(
          baseUrl: 'https://legacy.example.com',
          checkPath: '/app/config',
          responseParser: (json) => VersionCheckResponse(
            schemaVersion: 1,
            appId: 'com.example.app',
            platform: 'android',
            channel: VersionChannel.production,
            latest: VersionInfo.parse(json['latestVersion'] as String),
            minimum: VersionInfo.parse(json['minSupportedVersion'] as String),
            policy: VersionPolicy(
              mode: PolicyMode.custom,
              forceUpdate: json['force'] == true,
            ),
            updateUrl: json['storeLink'] as String?,
          ),
        ),
        platform: platform,
        httpClient: MockClient((req) async {
          expect(req.url.path, '/app/config');
          return http.Response(
            jsonEncode({
              'latestVersion': '2.9.0',
              'minSupportedVersion': '2.5.0',
              'force': true,
              'storeLink': 'https://x/y',
            }),
            200,
          );
        }),
      );
      final r = await m.checkVersion();
      // Installed 2.4.1 is below the mapped minimum 2.5.0 with force on.
      expect(r.status, UpdateStatus.updateRequired);
      expect(r.latest, VersionInfo.parse('2.9.0'));
      expect(r.minimum, VersionInfo.parse('2.5.0'));
      expect(r.updateUrl, 'https://x/y');
    });

    test(
      'a throwing responseParser is a response failure, not a crash',
      () async {
        final m = VersionManager(
          VersionManagerConfig(
            baseUrl: 'https://legacy.example.com',
            responseParser: (json) => throw FormatException('nope'),
          ),
          platform: platform,
          httpClient: MockClient((_) async => http.Response('{}', 200)),
        );
        final r = await m.checkVersion();
        expect(r.status, UpdateStatus.checkFailed);
        expect(r.error, isA<VersionResponseException>());
      },
    );
  });
}
