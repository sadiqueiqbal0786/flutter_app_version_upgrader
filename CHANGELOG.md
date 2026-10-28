## 0.3.0

- `VersionSource`: plug in any policy source (Firebase Remote Config, GraphQL,
  a bundled file) via `VersionManager.initialize(..., source: ...)`.
- `VersionManagerConfig.responseParser`: map a custom JSON shape while
  keeping the built-in HTTP client.
- `VersionApiClient.fetch` now takes a `VersionCheckRequest`; the `apiClient`
  constructor parameter is deprecated in favour of `source`.

## 0.2.3

- The reference backend moved to its own repository
  (flutter_app_version_upgrader_backend). This package now contains only the
  plugin. No code changes.

## 0.2.2

- README rewritten as a step-by-step guide: quick start, endpoint options,
  full configuration reference, UI customisation, troubleshooting. No code
  changes.

## 0.2.1

- README: correct install snippet, add badges and author section. No code changes.

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
