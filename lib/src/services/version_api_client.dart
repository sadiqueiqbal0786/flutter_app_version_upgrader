import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/version_channel.dart';
import '../models/version_check_response.dart';
import '../models/version_info.dart';
import '../version_manager_config.dart';

/// Thrown when the version API cannot be reached or returns an error.
class VersionApiException implements Exception {
  /// Creates a [VersionApiException].
  const VersionApiException(this.message, {this.statusCode, this.cause});

  /// Human-readable explanation.
  final String message;

  /// HTTP status code, when the server answered.
  final int? statusCode;

  /// The underlying error, when the request itself failed.
  final Object? cause;

  @override
  String toString() =>
      'VersionApiException: $message'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}

/// Talks to `GET /v1/version/check`.
///
/// The client sends only public information: app id, platform, channel and
/// the installed version. Store credentials never leave the backend.
class VersionApiClient {
  /// Creates a [VersionApiClient].
  VersionApiClient({required this.config, http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  /// The configuration in effect.
  final VersionManagerConfig config;

  final http.Client _http;
  final bool _ownsClient;

  /// Builds the request URL for the given parameters.
  Uri buildUri({
    required String appId,
    required String platform,
    required VersionChannel channel,
    required VersionInfo current,
  }) {
    final base = Uri.parse(config.baseUrl);
    final path = _joinPath(base.path, config.checkPath);
    return base.replace(
      path: path,
      queryParameters: {
        ...base.queryParameters,
        'app_id': appId,
        'platform': platform,
        'channel': channel.wireName,
        'version': current.version.toString(),
        if (current.build != null) 'build': current.build.toString(),
      },
    );
  }

  static String _joinPath(String a, String b) {
    final left = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
    final right = b.startsWith('/') ? b : '/$b';
    return '$left$right';
  }

  /// Fetches and parses the version policy for the installed app.
  ///
  /// Throws [VersionApiException] on transport or HTTP errors and
  /// [VersionResponseException] on an unusable body.
  Future<VersionCheckResponse> fetch({
    required String appId,
    required String platform,
    required VersionChannel channel,
    required VersionInfo current,
  }) async {
    final uri = buildUri(
      appId: appId,
      platform: platform,
      channel: channel,
      current: current,
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Id': appId,
      'X-App-Platform': platform,
      'X-App-Channel': channel.wireName,
      'X-App-Version': current.version.toString(),
      if (current.build != null) 'X-App-Build': current.build.toString(),
      if (config.apiKey != null) 'X-Api-Key': config.apiKey!,
      ...config.headers,
    };

    http.Response response;
    try {
      response = await _http.get(uri, headers: headers).timeout(config.timeout);
    } on TimeoutException catch (e) {
      throw VersionApiException(
        'Request timed out after ${config.timeout.inMilliseconds} ms',
        cause: e,
      );
    } on Object catch (e) {
      throw VersionApiException('Request failed: $e', cause: e);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VersionApiException(
        'Server returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final validator = config.responseValidator;
    if (validator != null && !validator(response.body, response.headers)) {
      throw const VersionApiException('Response failed validation');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw VersionResponseException('Body is not valid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw const VersionResponseException('Body is not a JSON object');
    }
    return VersionCheckResponse.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// Releases the underlying HTTP client if this instance created it.
  void close() {
    if (_ownsClient) _http.close();
  }
}
