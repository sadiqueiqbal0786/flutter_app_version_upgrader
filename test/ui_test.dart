import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_app_version_upgrader/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_platform.dart';
import 'version_check_response_test.dart' show sampleBody;

void main() {
  late FakePlatform platform;
  const config = VersionManagerConfig(baseUrl: 'https://versions.example.com');

  setUp(() => platform = FakePlatform());

  VersionManager managerFor(Map<String, dynamic> body, {int status = 200}) =>
      VersionManager(
        config,
        platform: platform,
        httpClient: MockClient((_) async => http.Response(jsonEncode(body), status)),
      );

  Map<String, dynamic> body({
    String latest = '2.7.0',
    String minimum = '2.5.0',
    bool force = true,
    String? notes,
    String? recommended,
  }) =>
      sampleBody(minimum: {'version': minimum, 'build': 250})
        ..['latest'] = {'version': latest, 'build': 270}
        ..['policy'] = {'mode': 'custom', 'force_update': force, 'update_message': 'Admin says update.'}
        ..['update'] = {'url': 'https://example.com/store', 'release_notes': ?notes}
        ..['recommended'] = recommended == null ? null : {'version': recommended};

  Widget app(VersionManager m, {UpgraderOptions options = const UpgraderOptions(), UpgraderStyle style = const UpgraderStyle(), UpgraderTexts texts = const UpgraderTexts(), RequiredUpdateBuilder? requiredBuilder, AvailableUpdateBuilder? availableBuilder, TargetPlatform? targetPlatform}) =>
      MaterialApp(
        theme: ThemeData(platform: targetPlatform),
        builder: (context, child) => VersionUpgrader(
          manager: m,
          options: options,
          style: style,
          texts: texts,
          requiredBuilder: requiredBuilder,
          availableBuilder: availableBuilder,
          child: child!,
        ),
        home: const Scaffold(body: Text('HOME')),
      );

  group('VersionUpgrader', () {
    testWidgets('blocks with the admin message when an update is required', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.4.0', buildNumber: 240, platform: 'android');
      final m = managerFor(body());
      await tester.pumpWidget(app(m));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsNothing);
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Admin says update.'), findsOneWidget);
      expect(find.text('2.4.0 (240)'), findsOneWidget, reason: 'installed chip');
      expect(find.text('2.7.0 (270)'), findsOneWidget, reason: 'latest chip');

      await tester.tap(find.text('Update now'));
      await tester.pump();
      expect(platform.opened, ['https://example.com/store']);
    });

    testWidgets('shows the soft prompt with skip and later when an update is available', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.6.0', buildNumber: 260, platform: 'android');
      final m = managerFor(body(notes: 'Faster sync'));
      await tester.pumpWidget(app(m));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text("What's new"), findsOneWidget);
      expect(find.text('Faster sync'), findsOneWidget);
      expect(find.text('Admin says update.'), findsNothing, reason: 'server message is for the blocking screen');

      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      expect(platform.store.keys, contains('flutter_app_version_upgrader.prompt'));

      // A fresh widget + check for the same latest stays silent.
      final m2 = managerFor(body(notes: 'Faster sync'));
      await tester.pumpWidget(app(m2));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // A newer latest shows again.
      final m3 = managerFor(body(latest: '2.8.0'));
      await tester.pumpWidget(app(m3));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('later snoozes for the configured duration', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.6.0', buildNumber: 260, platform: 'android');
      await tester.pumpWidget(app(managerFor(body())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      await tester.pumpWidget(app(managerFor(body())));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing, reason: 'still snoozed');
    });

    testWidgets('nothing is shown when up to date or when the check fails open', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.7.0', buildNumber: 270, platform: 'android');
      await tester.pumpWidget(app(managerFor(body())));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.textContaining('Update'), findsNothing);

      await tester.pumpWidget(app(managerFor({}, status: 503)));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('fail-closed shows the retry screen', (tester) async {
      final m = VersionManager(
        config.copyWith(failurePolicy: FailurePolicy.closed),
        platform: platform,
        httpClient: MockClient((_) async => http.Response('', 503)),
      );
      await tester.pumpWidget(app(m));
      await tester.pumpAndSettle();
      expect(find.text('Unable to verify version'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('custom texts, dialog presentation and soft-prompt-only-below-recommended', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.6.0', buildNumber: 260, platform: 'android');
      // Below latest but not below recommended → silent.
      await tester.pumpWidget(app(
        managerFor(body(recommended: '2.6.0')),
        options: const UpgraderOptions(softPromptOnlyBelowRecommended: true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      await tester.pumpWidget(app(
        managerFor(body(recommended: '2.7.0')),
        options: const UpgraderOptions(softPromptOnlyBelowRecommended: true, allowSkipVersion: false),
        style: const UpgraderStyle(presentation: UpgraderPresentation.dialog, accentColor: Colors.purple),
        texts: const UpgraderTexts(availableTitle: 'Neue Version', availableMessage: 'Version {latest} ist da.', updateButton: 'Jetzt', laterButton: 'Später'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Neue Version'), findsOneWidget);
      expect(find.text('Version 2.7.0 ist da.'), findsOneWidget);
      expect(find.text('Jetzt'), findsOneWidget);
      expect(find.text('Später'), findsOneWidget);
      expect(find.text('Skip this version'), findsNothing);
    });

    testWidgets('builders replace the built-in widgets but keep the logic', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.4.0', buildNumber: 240, platform: 'android');
      await tester.pumpWidget(app(
        managerFor(body()),
        requiredBuilder: (context, result, onUpdate) => Scaffold(
          body: TextButton(onPressed: onUpdate, child: Text('MINE ${result.minimum}')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('MINE 2.5.0 (250)'), findsOneWidget);
      await tester.tap(find.text('MINE 2.5.0 (250)'));
      await tester.pump();
      expect(platform.opened, hasLength(1));

      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.6.0', buildNumber: 260, platform: 'android');
      await tester.pumpWidget(app(
        managerFor(body()),
        availableBuilder: (context, result, onUpdate, onLater, onSkip) => Align(
          alignment: Alignment.bottomCenter,
          child: Material(child: TextButton(onPressed: onSkip, child: const Text('CUSTOM SKIP'))),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('CUSTOM SKIP'), findsOneWidget);
      await tester.tap(find.text('CUSTOM SKIP'));
      await tester.pumpAndSettle();
      expect(find.text('CUSTOM SKIP'), findsNothing);
      expect(platform.store.keys, contains('flutter_app_version_upgrader.prompt'));
    });

    testWidgets('uses Cupertino secondary buttons on iOS and Material ones on Android', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.6.0', buildNumber: 260, platform: 'ios');
      await tester.pumpWidget(app(managerFor(body()), targetPlatform: TargetPlatform.iOS));
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsNothing);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'CupertinoButton'), findsNWidgets(2));
      expect(find.byType(UpgraderPrimaryButton), findsOneWidget);

      await tester.pumpWidget(app(managerFor(body()), targetPlatform: TargetPlatform.android));
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsNWidgets(2));
    });

    testWidgets('version line and chips can be toggled', (tester) async {
      platform.appInfo = const AppInfo(packageName: 'a', versionName: '2.4.0', buildNumber: 240, platform: 'android');
      await tester.pumpWidget(app(
        managerFor(body()),
        style: const UpgraderStyle(showVersionChips: false, animateHero: false, blurBackdrop: false),
        texts: const UpgraderTexts(versionLine: 'Installed {current} · Latest {latest}'),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(VersionChips), findsNothing);
      expect(find.text('Installed 2.4.0 · Latest 2.7.0'), findsOneWidget);
    });

    testWidgets('renders the child untouched without an initialised manager', (tester) async {
      VersionManager.reset();
      await tester.pumpWidget(const MaterialApp(home: VersionUpgrader(child: Text('HOME'))));
      await tester.pump();
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('UpgraderPromptStore', () {
    test('skip and remind-later persist and expire', () async {
      var now = DateTime.utc(2026, 1, 1);
      final store = UpgraderPromptStore(platform, clock: () => now);
      final v = VersionInfo.parse('2.7.0', build: 270);
      expect(await store.isSuppressed(v), isFalse);
      await store.remindLater(const Duration(hours: 2));
      expect(await store.isSuppressed(v), isTrue);
      now = now.add(const Duration(hours: 3));
      expect(await store.isSuppressed(v), isFalse);
      await store.skip(v);
      expect(await store.isSuppressed(v), isTrue);
      expect(await store.isSuppressed(VersionInfo.parse('2.8.0')), isFalse);
      await store.clear();
      expect(await store.isSuppressed(v), isFalse);
    });
  });
}
