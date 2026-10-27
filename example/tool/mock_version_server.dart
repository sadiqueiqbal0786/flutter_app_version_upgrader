// A tiny stand-in for the version API, for trying the example app locally.
//
//   dart run tool/mock_version_server.dart [--port 8080] [--mode custom|auto_latest]
//         [--latest 2.7.0:270] [--minimum 2.5.0:250] [--no-force]
//
// It answers GET /v1/version/check with the documented payload and echoes
// the query it received to stdout, so you can watch what the plugin sends.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var port = 8080;
  var mode = 'custom';
  var latest = ('2.7.0', 270);
  var minimum = ('2.5.0', 250);
  var force = true;

  (String, int) parsePair(String s) {
    final parts = s.split(':');
    return (parts[0], parts.length > 1 ? int.parse(parts[1]) : 0);
  }

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--mode':
        mode = args[++i];
      case '--latest':
        latest = parsePair(args[++i]);
      case '--minimum':
        minimum = parsePair(args[++i]);
      case '--no-force':
        force = false;
    }
  }
  if (mode == 'auto_latest') minimum = latest;

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Mock version API listening on http://0.0.0.0:$port');
  stdout.writeln('  latest=$latest minimum=$minimum mode=$mode force=$force');

  await for (final request in server) {
    final q = request.uri.queryParameters;
    stdout.writeln('${request.method} ${request.uri}');

    if (request.uri.path == '/health') {
      request.response
        ..statusCode = 200
        ..write('ok');
      await request.response.close();
      continue;
    }
    if (request.method != 'GET' || request.uri.path != '/v1/version/check') {
      request.response.statusCode = 404;
      await request.response.close();
      continue;
    }

    final platform = q['platform'] ?? 'android';
    final appId = q['app_id'] ?? 'unknown';
    final storeUrl = platform == 'ios'
        ? 'https://apps.apple.com/app/id000000000'
        : 'https://play.google.com/store/apps/details?id=$appId';

    final body = {
      'schema_version': 1,
      'app': {
        'id': appId,
        'platform': platform,
        'channel': q['channel'] ?? 'production',
      },
      'latest': {'version': latest.$1, 'build': latest.$2},
      'minimum': {'version': minimum.$1, 'build': minimum.$2},
      'recommended': {'version': latest.$1, 'build': latest.$2},
      'policy': {
        'mode': mode,
        'force_update': force,
        'enabled': true,
        'update_message': 'Please update the application to continue.',
      },
      'update': {
        'url': storeUrl,
        'release_notes': 'Performance improvements and bug fixes.',
      },
      'server_time': DateTime.now().toUtc().toIso8601String(),
    };

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..headers.set('Cache-Control', 'no-store')
      ..write(jsonEncode(body));
    await request.response.close();
  }
}
