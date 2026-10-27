## 0.2.0

- Optional UI library (`package:flutter_app_version_upgrader/ui.dart`):
  `VersionUpgrader` wrapper, `UpdateRequiredScreen`, `UpdateAvailablePrompt`
  (bottom sheet, dialog or full screen), `UpgraderStyle`, `UpgraderTexts`,
  `UpgraderOptions`, builder overrides, persisted "skip this version" and
  "later".
- `VersionManager.platform` exposes the active platform implementation.

## 0.1.0

Initial release.

- `VersionManager` with `initialize`, `check`, `openStore`, `clearCache`.
- Semantic version parser and comparison with build-number tie-breaking.
- Policy modes `auto_latest`, `custom`, `age_based`; `recommended` version.
- Native cache (SharedPreferences / UserDefaults) with TTL and stale fallback.
- Fail-open / fail-closed behaviour when neither API nor cache is available.
- Store launcher for Android and iOS.
- Response validation hook for signed responses.
- Guarded fallback on web and desktop: never throws, fails open, optional
  in-memory operation with `appId` + `currentVersionOverride`.
