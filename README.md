# flutter_app_version_upgrader

[![pub package](https://img.shields.io/pub/v/flutter_app_version_upgrader.svg)](https://pub.dev/packages/flutter_app_version_upgrader)
[![CI](https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader/actions/workflows/ci.yml/badge.svg)](https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader/actions/workflows/ci.yml)
![Android](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/platform-iOS-000000?logo=apple&logoColor=white)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Force and soft app updates, controlled from your server instead of a new
release. By [Sadique Iqbal](https://github.com/sadiqueiqbal0786).

| Update required | Update available | Dark mode |
|---|---|---|
| ![Update required](https://raw.githubusercontent.com/sadiqueiqbal0786/flutter_app_version_upgrader/main/doc/screenshots/required_light.png) | ![Update available](https://raw.githubusercontent.com/sadiqueiqbal0786/flutter_app_version_upgrader/main/doc/screenshots/available_light.png) | ![Dark](https://raw.githubusercontent.com/sadiqueiqbal0786/flutter_app_version_upgrader/main/doc/screenshots/available_dark.png) |

## What it does

Your app asks a small HTTPS endpoint two questions on every launch: what is
the **latest** published version, and what is the **minimum** version still
allowed to run. The plugin compares both with the installed version and
gives you a decision:

| Decision | Meaning | Built-in UI |
|---|---|---|
| `updateRequired` | Installed version is below the minimum | Full-screen page, cannot be dismissed |
| `updateAvailable` | A newer version exists but this one may run | Bottom sheet with Update, Later, Skip this version |
| `upToDate` | Nothing newer | Nothing |
| `checkFailed` | Endpoint unreachable and no cache | Nothing (fails open by default) |

Change the minimum on the server and every running app follows on its next
launch. No store submission, no app rebuild.

**Highlights**

- Correct semantic version comparison (`2.10.0` is newer than `2.9.0`), build
  numbers as a tie-breaker.
- Latest, recommended and minimum versions kept separate, plus
  `auto_latest`, `custom` and `age_based` policy modes.
- Channels (`production`, `beta`, `alpha`, `internal`) so TestFlight or Play
  testers are measured against their own track.
- Last known policy cached natively with a TTL; outages never lock users
  out unless you choose fail-closed.
- Opens the Play Store, App Store or TestFlight page.
- Optional, themeable, platform-adaptive UI, or bring your own widgets.
- No store credentials or secrets inside the app.
- Web and desktop never throw: the plugin steps aside there.

## Quick start

### 1. Install

```yaml
dependencies:
  flutter_app_version_upgrader: ^0.3.2
```

Requirements: Flutter 3.19+ (Dart 3.3+), Android `minSdk 21`, iOS 15.
Nothing to add to `AndroidManifest.xml` or `Info.plist`.

### 2. Initialise once, before `runApp`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_app_version_upgrader/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await VersionManager.initialize(
    const VersionManagerConfig(
      baseUrl: 'https://versions.example.com', // your endpoint, see step 4
      channel: VersionChannel.production,
    ),
  );

  runApp(const MyApp());
}
```

### 3. Wrap your app

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Covers every route, so a required update blocks the whole app.
      builder: (context, child) => VersionUpgrader(child: child!),
      home: const HomePage(),
    );
  }
}
```

That is the whole integration. On launch and on every return to the
foreground the plugin checks, and the built-in UI shows the right thing.

### 4. Give it an endpoint

The plugin calls:

```text
GET {baseUrl}/v1/version/check?app_id=<id>&platform=<android|ios>&channel=<channel>&version=<installed>&build=<installed build>
```

and expects this JSON (full contract in
[doc/api_contract.md](https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader/blob/main/doc/api_contract.md)):

```json
{
  "schema_version": 1,
  "app": { "id": "com.example.app", "platform": "android", "channel": "production" },
  "latest":  { "version": "2.7.0", "build": 270 },
  "minimum": { "version": "2.5.0", "build": 250 },
  "policy":  { "mode": "custom", "force_update": true, "update_message": "Please update to continue." },
  "update":  { "url": "https://play.google.com/store/apps/details?id=com.example.app", "release_notes": "Bug fixes." }
}
```

Pick whichever of these suits you:

| Option | Effort | You get |
|---|---|---|
| **A. Static JSON file** on any host (Firebase Hosting, S3, GitHub Pages, your API) | Minutes | Remote-controlled minimum and latest. You edit the file when you release. Set `checkPath` to the file's path. |
| **B. Reference backend**, a separate project: [flutter_app_version_upgrader_backend](https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader_backend) | An afternoon | Latest discovered automatically from Google Play, App Store and TestFlight, age-based minimum, admin dashboard, installed-version stats. Nothing to do per release. |
| **C. Your own API** | Depends | Return the JSON above from an endpoint you already run. |

For option A with a static file:

```dart
VersionManagerConfig(
  baseUrl: 'https://cdn.example.com',
  checkPath: '/app-versions/android-production.json', // one file per platform/channel
)
```

## Bring your own server

The plugin never depends on any particular backend. Three levels of
freedom, from least to most code:

**Same JSON, any host.** Return the contract above from anything: a static
file, a Lambda, a route in your existing API. No plugin code beyond
`baseUrl` and `checkPath`.

**Your JSON shape, same HTTP client.** Already have an endpoint that says
`{"latestVersion": "2.9.0", "minSupportedVersion": "2.5.0", ...}`? Map it:

```dart
VersionManagerConfig(
  baseUrl: 'https://api.example.com',
  checkPath: '/mobile/app-config',
  responseParser: (json) => VersionCheckResponse(
    schemaVersion: 1,
    appId: 'com.example.app',
    platform: 'android',
    channel: VersionChannel.production,
    latest: VersionInfo.parse(json['latestVersion'] as String),
    minimum: VersionInfo.parse(json['minSupportedVersion'] as String),
    policy: VersionPolicy(mode: PolicyMode.custom, forceUpdate: json['force'] == true),
    updateUrl: json['storeLink'] as String?,
    releaseNotes: json['notes'] as String?,
  ),
)
```

**Not HTTP at all.** Implement `VersionSource` and hand it to
`initialize`. Firebase Remote Config, GraphQL, gRPC, a bundled config file,
anything:

```dart
class RemoteConfigSource implements VersionSource {
  @override
  Future<VersionCheckResponse> fetch(VersionCheckRequest request) async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.fetchAndActivate();
    return VersionCheckResponse(
      schemaVersion: 1,
      appId: request.appId,
      platform: request.platform,
      channel: request.channel,
      latest: VersionInfo.parse(rc.getString('latest_version')),
      minimum: VersionInfo.parse(rc.getString('min_version')),
      policy: VersionPolicy(mode: PolicyMode.custom, forceUpdate: rc.getBool('force_update')),
      updateUrl: rc.getString('store_url'),
    );
  }
}

await VersionManager.initialize(
  const VersionManagerConfig(baseUrl: 'unused'),
  source: RemoteConfigSource(),
);
```

`VersionSource.fromCallback((request) async => ...)` does the same without
a class. Whatever the source, the plugin still handles caching, fail-open,
comparison, skip and snooze, and the UI.

## Configuration reference

Every option of `VersionManagerConfig`:

| Option | Default | What it does |
|---|---|---|
| `baseUrl` | required | Base URL of your endpoint (any value when a custom `source` is used) |
| `appId` | package name / bundle id | Value sent as `app_id` |
| `channel` | `production` | `production`, `beta`, `alpha`, `internal`. Keep `production` for anything that may be promoted to a store; see "Choosing the channel" |
| `checkPath` | `/v1/version/check` | Path appended to `baseUrl` |
| `apiKey` | none | Sent as `X-Api-Key` |
| `headers` | `{}` | Extra headers on every request |
| `timeout` | 10 s | Network timeout |
| `cacheTtl` | 24 h | How long the last answer is considered fresh |
| `allowStaleCache` | `true` | When the endpoint is down, reuse an expired cache rather than fail |
| `failurePolicy` | `open` | `open` lets the app run when nothing is known; `closed` blocks |
| `responseValidator` | none | Callback to verify a signature before trusting a response |
| `responseParser` | none | Map your own JSON shape to the plugin's model |
| `appStoreId` | none | Numeric App Store id, fallback link on iOS when the server sends no `update.url` |
| `currentVersionOverride` | none | Pretend to be another version (debug menus, tests, desktop) |
| `logger` | none | Receives diagnostic messages |

### Choosing the channel

Keep `production` for any build that could ever reach a store. On iOS the
TestFlight build is the very binary Apple later releases, and on Android a
test-track bundle is often promoted unchanged; a build compiled with `beta`
would keep checking the beta track after it went live. A TestFlight build
on `production` is usually newer than the App Store version and simply
reports up to date, which is correct.

Use `beta`, `alpha` or `internal` only for builds that will never be
promoted, for example a nightly for internal testers. Pass it at build
time so it cannot leak into a store build by accident:

```sh
flutter build apk --flavor nightly --dart-define=VERSION_CHANNEL=internal
```

```dart
const channelName = String.fromEnvironment('VERSION_CHANNEL', defaultValue: 'production');
VersionManagerConfig(
  baseUrl: '...',
  channel: VersionChannel.fromWireName(channelName) ?? VersionChannel.production,
)
```

## Customising the UI

`VersionUpgrader` has three layers. Use the lightest one that gets you
there.

### Wording and localisation

Every string is replaceable. `{current}`, `{latest}` and `{minimum}` are
filled in for you.

```dart
VersionUpgrader(
  texts: const UpgraderTexts(
    requiredTitle: 'Update required',
    requiredMessage: 'Version {minimum} or newer is needed to continue.',
    availableTitle: 'A new version is ready',
    availableMessage: 'Version {latest} has the latest improvements.',
    updateButton: 'Update now',
    laterButton: 'Not now',
    skipButton: 'Skip this version',
    releaseNotesTitle: "What's new",
  ),
  child: child!,
)
```

The server's `update_message`, when present, replaces `requiredMessage` on
the blocking page. Set `useServerMessageForSoftPrompt: true` to use it on
the sheet as well.

### Look and feel

Colours and type come from your `Theme` by default, in light and dark.
Override what you need:

```dart
VersionUpgrader(
  style: UpgraderStyle(
    accentColor: const Color(0xFF0B5FFF),
    heroGradient: const [Color(0xFF0B5FFF), Color(0xFF7C4DFF)],
    presentation: UpgraderPresentation.bottomSheet, // or .dialog, .fullScreen
    illustration: Image.asset('assets/update.png', height: 120), // replaces the icon
    borderRadius: BorderRadius.circular(20),
    buttonBorderRadius: BorderRadius.circular(12),
    titleStyle: const TextStyle(fontFamily: 'YourBrandFont'),
    showVersionChips: true,
    blurBackdrop: true,
    animateHero: true,
    platformAdaptive: true, // Cupertino secondary buttons on iOS
  ),
  child: child!,
)
```

### Behaviour

```dart
VersionUpgrader(
  options: const UpgraderOptions(
    checkOnStart: true,
    checkOnResume: true,
    initialDelay: Duration(seconds: 1),      // let a splash finish first
    showSoftPrompt: true,                    // false = only ever block
    allowSkipVersion: true,
    allowLater: true,
    remindLaterAfter: Duration(days: 1),
    softPromptOnlyBelowRecommended: false,   // true = nag only below `recommended`
  ),
  onResult: (result) => analytics.log('version_check', result.toJson()),
  onUpdatePressed: (result) async {
    // Return true to handle it yourself (in-app update, custom route).
    return false;
  },
  onSkipped: (version) => analytics.log('version_skipped', {'v': '$version'}),
  child: child!,
)
```

"Skip this version" and "Later" are persisted natively, so the same version
is never offered twice and the reminder survives restarts.

### Your own widgets

Keep the checking, caching, skip and snooze logic but draw everything
yourself:

```dart
VersionUpgrader(
  requiredBuilder: (context, result, onUpdate) => MyBlockingPage(
    message: result.updateMessage,
    latest: result.latest,
    onUpdate: onUpdate,
  ),
  availableBuilder: (context, result, onUpdate, onLater, onSkip) => MyUpdateSheet(
    result: result,
    onUpdate: onUpdate,
    onLater: onLater,
    onSkip: onSkip,
  ),
  child: child!,
)
```

The pieces of the default UI (`UpdateRequiredScreen`,
`UpdateAvailablePrompt`, `UpgraderContent`, `UpgraderHero`, `VersionChips`,
`ReleaseNotesCard`, `UpgraderPrimaryButton`) are exported for reuse inside
your own layouts.

### No UI at all

Skip the `ui.dart` import and drive your own flow from the result:

```dart
final result = await VersionManager.check();

switch (result.status) {
  case UpdateStatus.updateRequired:
    showMyBlockingDialog(result.updateMessage);
    await VersionManager.openStore(result);
  case UpdateStatus.updateAvailable:
    showMySnackbar('Version ${result.latest} is available');
  case UpdateStatus.upToDate:
  case UpdateStatus.checkFailed:
    break;
}
```

`result` carries `current`, `latest`, `minimum`, `recommended`, `policy`,
`updateUrl`, `updateMessage`, `releaseNotes`, `source` (`network`, `cache`,
`none`), `isStale`, `isBlocked`, and the convenience getters
`isUpdateRequired`, `isUpdateAvailable`, `isBelowMinimum`,
`isBelowRecommended`.

## How a decision is made

1. If the policy is disabled, never `updateRequired`.
2. `current < minimum` and `policy.forceUpdate` → `updateRequired`.
3. `current < latest` → `updateAvailable`.
4. Otherwise → `upToDate`.

If the endpoint cannot be reached: use the cache (fresh, or stale when
`allowStaleCache` is on). With no cache at all: `checkFailed`, and
`isBlocked` follows `failurePolicy`.

Versions are compared as semantic versions first; the build number only
breaks ties within the same version, matching how both stores behave.

## Platform notes

| Platform | Support |
|---|---|
| Android (minSdk 21) | Native. Reads `versionName` / `versionCode`, caches in `SharedPreferences`, opens `market://` then the Play web page |
| iOS | Native. Reads `CFBundleShortVersionString` / `CFBundleVersion`, caches in `UserDefaults`, opens the server's URL, else `itms-apps://` for the App Store id |
| Web, macOS, Windows, Linux | Guarded. No exception is thrown; `check()` fails open. Set `appId` and `currentVersionOverride` to run checks there with an in-memory cache. `openStore` returns `false` |

`VersionManager.isPlatformSupported` tells you which case applies at
runtime.

## Security

- Store credentials stay on the server. The app only sends its own
  version, platform and channel.
- Use HTTPS. Add an `X-Api-Key` with `apiKey`, or any header with `headers`.
- To verify signed responses, implement `responseValidator`. The reference
  backend, for example, signs with HMAC-SHA256 over `"<timestamp>.<body>"` in the
  `X-Signature` header:

```dart
responseValidator: (body, headers) {
  final ts = headers['x-signature-timestamp'];
  final sig = headers['x-signature'];
  if (ts == null || sig == null) return false;
  final mac = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode('$ts.$body'));
  return sig == 'sha256=$mac';
}
```

- Certificate pinning is deliberately not built in.

## Testing your integration

- Use `currentVersionOverride` to make the app believe it is an old
  version and watch the blocking page appear.
- Run the mock endpoint shipped with the example:
  `dart run example/tool/mock_version_server.dart --latest 2.7.0:270 --minimum 2.5.0:250`
  and point `baseUrl` at `http://10.0.2.2:8080` (Android emulator) or
  `http://localhost:8080` (iOS simulator).
- `VersionManager` accepts an injected `http.Client` and platform, so unit
  tests need no network. See `test/` for examples.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Nothing ever shows | `checkFailed`: the URL is wrong or unreachable. Pass a `logger` and read the messages |
| Shows "update required" on a fresh install | The server's `minimum` is above the installed version. Check `policy.mode` and the data for that channel |
| A build compiled with `beta` keeps asking about the beta track after it shipped | Store builds must use `production`; `beta` is only for builds that are never promoted |
| `2.10.0` treated as older than `2.9.0` | Your server compares strings. Return proper versions; the plugin compares them correctly |
| Soft prompt never returns after tapping Skip | That is by design, per version. A newer `latest` shows it again. Call `UpgraderPromptStore(VersionManager.instance.platform).clear()` to reset |
| iOS opens Safari instead of the App Store | Send `https://apps.apple.com/app/id<ID>` or set `appStoreId` so the `itms-apps` link is used |

## Reference backend

[flutter_app_version_upgrader_backend](https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader_backend) is a separate, optional
FastAPI service that polls Google Play, App Store Connect and TestFlight,
stores releases, applies `auto_latest` / `custom` / `age_based` policies,
serves the endpoint above and ships an admin dashboard. It is not part of
this package; use it, a static file, or your own API.

## Author

**Sadique Iqbal** · [GitHub](https://github.com/sadiqueiqbal0786) · sadiqueiqbal.si@gmail.com

Issues and pull requests are welcome at the
[repository](https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader).

## License

MIT © 2026 Sadique Iqbal. See [LICENSE](LICENSE).
