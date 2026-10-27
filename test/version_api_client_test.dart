import 'dart:convert';

import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'version_check_response_test.dart' show sampleBody;

void main() {
  const config = VersionManagerConfig(
    baseUrl: 'https://versions.example.com/api/',
    apiKey: 'secret',
    headers: {'X-Tenant': 't1'},
  );
  final current = VersionInfo.parse('2.4.1', build: 241);

  group('VersionApiClient', () {
    test('builds the documented request', () async {
      http.Request? seen;
      final client = VersionApiClient(
        config: config,
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode(sampleBody()), 200);
        }),
      );

      await client.fetch(
        appId: 'com.example.app',
        platform: 'android',
        channel: VersionChannel.beta,
        current: current,
      );

      final uri = seen!.url;
      expect(uri.host, 'versions.example.com');
      expect(uri.path, '/api/v1/version/check');
      expect(uri.queryParameters, {
        'app_id': 'com.example.app',
        'platform': 'android',
        'channel': 'beta',
        'version': '2.4.1',
        'build': '241',
      });
      expect(seen!.headers['X-Api-Key'], 'secret');
      expect(seen!.headers['X-Tenant'], 't1');
      expect(seen!.headers['X-App-Version'], '2.4.1');
      expect(seen!.headers['Accept'], 'application/json');
    });

    test('wraps HTTP errors', () async {
      final client = VersionApiClient(
        config: config,
        httpClient: MockClient((_) async => http.Response('nope', 503)),
      );
      expect(
        () => client.fetch(
          appId: 'a',
          platform: 'ios',
          channel: VersionChannel.production,
          current: current,
        ),
        throwsA(isA<VersionApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)),
      );
    });

    test('wraps transport errors', () async {
      final client = VersionApiClient(
        config: config,
        httpClient: MockClient((_) async => throw http.ClientException('down')),
      );
      expect(
        () => client.fetch(
          appId: 'a',
          platform: 'ios',
          channel: VersionChannel.production,
          current: current,
        ),
        throwsA(isA<VersionApiException>()),
      );
    });

    test('rejects invalid JSON', () async {
      final client = VersionApiClient(
        config: config,
        httpClient: MockClient((_) async => http.Response('<html>', 200)),
      );
      expect(
        () => client.fetch(
          appId: 'a',
          platform: 'ios',
          channel: VersionChannel.production,
          current: current,
        ),
        throwsA(isA<VersionResponseException>()),
      );
    });

    test('honours the response validator', () async {
      final client = VersionApiClient(
        config: config.copyWith(
          responseValidator: (body, headers) => headers['x-signature'] == 'ok',
        ),
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode(sampleBody()), 200,
                headers: {'x-signature': 'bad'})),
      );
      expect(
        () => client.fetch(
          appId: 'a',
          platform: 'ios',
          channel: VersionChannel.production,
          current: current,
        ),
        throwsA(isA<VersionApiException>()),
      );
    });

    test('times out', () async {
      final client = VersionApiClient(
        config: config.copyWith(timeout: const Duration(milliseconds: 20)),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );
      expect(
        () => client.fetch(
          appId: 'a',
          platform: 'ios',
          channel: VersionChannel.production,
          current: current,
        ),
        throwsA(isA<VersionApiException>()
            .having((e) => e.message, 'message', contains('timed out'))),
      );
    });
  });
}
