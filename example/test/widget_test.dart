import 'package:flutter/material.dart';
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_app_version_upgrader/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('force update screen shows the admin message', (tester) async {
    final result = VersionCheckResult.evaluate(
      current: VersionInfo.parse('2.4.0'),
      response: VersionCheckResponse(
        schemaVersion: 1,
        appId: 'a',
        platform: 'android',
        channel: VersionChannel.production,
        latest: VersionInfo.parse('2.7.0'),
        minimum: VersionInfo.parse('2.5.0'),
        policy: const VersionPolicy(
          mode: PolicyMode.custom,
          forceUpdate: true,
          updateMessage: 'Please update to continue.',
        ),
      ),
      source: CheckSource.network,
      checkedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(home: UpdateRequiredScreen(result: result, onUpdate: () {})),
    );

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Please update to continue.'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });
}
