import 'package:flutter/services.dart';
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterAppVersionUpgrader();
  final channel = platform.methodChannel;
  final calls = <MethodCall>[];
  final store = <String, String>{};

  setUp(() {
    calls.clear();
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
      switch (call.method) {
        case 'getAppInfo':
          return {
            'packageName': 'com.example.app',
            'versionName': '1.2.3',
            'buildNumber': 42,
            'platform': 'android',
          };
        case 'readCache':
          return store[args['key']];
        case 'writeCache':
          store[args['key']! as String] = args['value']! as String;
          return null;
        case 'clearCache':
          store.remove(args['key']);
          return null;
        case 'openStore':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getAppInfo maps the native payload', () async {
    final info = await platform.getAppInfo();
    expect(info.packageName, 'com.example.app');
    expect(info.versionName, '1.2.3');
    expect(info.buildNumber, 42);
    expect(info.platform, 'android');
    expect(info.toVersionInfo(), VersionInfo.parse('1.2.3', build: 42));
  });

  test('getAppInfo accepts a string build number', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return {
        'packageName': 'com.example.app',
        'versionName': '1.2.3',
        'buildNumber': '7',
        'platform': 'ios',
      };
    });
    expect((await platform.getAppInfo()).buildNumber, 7);
  });

  test('cache round-trips through the channel', () async {
    expect(await platform.readCache('k'), isNull);
    await platform.writeCache('k', 'v');
    expect(await platform.readCache('k'), 'v');
    await platform.clearCache('k');
    expect(await platform.readCache('k'), isNull);
  });

  test('openStore forwards only the provided arguments', () async {
    expect(await platform.openStore(url: 'https://x'), isTrue);
    expect(calls.single.method, 'openStore');
    expect(calls.single.arguments, {'url': 'https://x'});
  });

  test('default platform instance is the method channel', () {
    expect(
      FlutterAppVersionUpgraderPlatform.instance,
      isA<MethodChannelFlutterAppVersionUpgrader>(),
    );
  });
}
