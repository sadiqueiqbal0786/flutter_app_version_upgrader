import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'version_check_response_test.dart' show sampleBody;

void main() {
  const config = VersionManagerConfig(baseUrl: 'https://versions.example.com');
  final body = sampleBody(minimum: {'version': '2.5.0', 'build': 250});

  group('Unsupported platforms', () {
    test('isPlatformSupported is false on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(VersionManager.isPlatformSupported, isFalse);
    });

    test('isPlatformSupported is true on android and ios', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(VersionManager.isPlatformSupported, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(VersionManager.isPlatformSupported, isTrue);
    });

    test('check fails open without an override instead of throwing', () async {
      final m = VersionManager(
        config,
        platform: InMemoryFlutterAppVersionUpgraderPlatform(),
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode(body), 200),
        ),
      );
      final result = await m.checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.isBlocked, isFalse);
      expect(result.error, isA<UnsupportedError>());
      expect(await m.openStoreFor(result), isFalse);
      await m.clearCachedPolicy(); // must not throw
    });

    test('check runs with appId and currentVersionOverride', () async {
      http.Request? seen;
      final m = VersionManager(
        config.copyWith(
          appId: 'com.example.desktop',
          currentVersionOverride: VersionInfo.parse('2.4.0', build: 240),
        ),
        platform: InMemoryFlutterAppVersionUpgraderPlatform(),
        httpClient: MockClient((r) async {
          seen = r;
          return http.Response(jsonEncode(body), 200);
        }),
      );
      final result = await m.checkVersion();
      expect(result.status, UpdateStatus.updateRequired);
      expect(seen!.url.queryParameters['app_id'], 'com.example.desktop');

      // Cache lives in memory: an outage now falls back to it.
      final offline = VersionManager(
        config.copyWith(
          appId: 'com.example.desktop',
          currentVersionOverride: VersionInfo.parse('2.4.0', build: 240),
        ),
        platform: m.platformForTesting,
        httpClient: MockClient((_) async => http.Response('', 503)),
      );
      expect((await offline.checkVersion()).source, CheckSource.cache);
    });

    test('override without appId fails open with a clear error', () async {
      final m = VersionManager(
        config.copyWith(currentVersionOverride: VersionInfo.parse('1.0.0')),
        platform: InMemoryFlutterAppVersionUpgraderPlatform(),
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode(body), 200),
        ),
      );
      final result = await m.checkVersion();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.error, isA<UnsupportedError>());
    });

    test(
      'static initialize does not throw on an unsupported platform',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          VersionManager.reset();
        });
        final logs = <String>[];
        await VersionManager.initialize(
          config.copyWith(logger: (m, [e]) => logs.add(m)),
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(body), 200),
          ),
        );
        final result = await VersionManager.check();
        expect(result.status, UpdateStatus.checkFailed);
        expect(logs, contains(contains('initialize')));
      },
    );
  });
}
