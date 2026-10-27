// Runs on a real device or emulator:
//   flutter test integration_test/plugin_integration_test.dart
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final platform = FlutterAppVersionUpgraderPlatform.instance;

  testWidgets('getAppInfo returns the example app identity', (tester) async {
    final info = await platform.getAppInfo();
    expect(info.packageName, isNotEmpty);
    expect(info.versionName, isNotEmpty);
    expect(info.platform, anyOf('android', 'ios'));
    expect(info.toVersionInfo().version, isA<SemanticVersion>());
  });

  testWidgets('cache round-trips through native storage', (tester) async {
    const key = 'integration.test.key';
    await platform.clearCache(key);
    expect(await platform.readCache(key), isNull);
    await platform.writeCache(key, '{"hello":"world"}');
    expect(await platform.readCache(key), '{"hello":"world"}');
    await platform.clearCache(key);
    expect(await platform.readCache(key), isNull);
  });

  testWidgets('check fails open when the API is unreachable', (tester) async {
    final manager = VersionManager(
      const VersionManagerConfig(
        baseUrl: 'http://127.0.0.1:1',
        timeout: Duration(seconds: 2),
      ),
    );
    await manager.clearCachedPolicy();
    final result = await manager.checkVersion();
    expect(result.status, UpdateStatus.checkFailed);
    expect(result.isBlocked, isFalse);
    manager.dispose();
  });
}
