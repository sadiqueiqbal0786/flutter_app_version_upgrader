# Version API contract (schema version 1)

The plugin needs exactly one endpoint. Everything else (store aggregation,
policy engine, admin dashboard, release database) is backend-internal.

## Request

```text
GET /v1/version/check
```

Query parameters:

| Name | Example | Notes |
|---|---|---|
| `app_id` | `com.example.app` | Package name / bundle id, or the configured `appId` |
| `platform` | `android` or `ios` | |
| `channel` | `production` | One of `production`, `beta`, `alpha`, `internal` |
| `version` | `2.4.1` | Installed marketing version |
| `build` | `241` | Installed build number, omitted when unknown |

Headers:

| Header | Notes |
|---|---|
| `Accept: application/json` | |
| `X-App-Id`, `X-App-Platform`, `X-App-Channel`, `X-App-Version`, `X-App-Build` | Same values as the query, for log and auth middleware |
| `X-Api-Key` | Present when `VersionManagerConfig.apiKey` is set |
| any extra | From `VersionManagerConfig.headers` |

## Response

`200 OK`, `Content-Type: application/json`:

```json
{
  "schema_version": 1,

  "app": {
    "id": "com.example.app",
    "platform": "android",
    "channel": "production"
  },

  "latest":      { "version": "2.7.0", "build": 270 },
  "minimum":     { "version": "2.5.0", "build": 250 },
  "recommended": { "version": "2.7.0", "build": 270 },

  "policy": {
    "mode": "custom",
    "force_update": true,
    "enabled": true,
    "update_message": "Please update the application to continue."
  },

  "update": {
    "url": "https://play.google.com/store/apps/details?id=com.example.app",
    "release_notes": "Bug fixes."
  },

  "server_time": "2026-10-27T05:30:00Z"
}
```

Field rules:

- `schema_version` — the client rejects values greater than it supports and
  falls back to its cache.
- `latest` — required. `version` must be parsable as semver (`major.minor.patch`,
  optional `-prerelease`). `build` is optional but recommended.
- `minimum` — optional. When omitted the client treats `minimum = latest`
  (the `auto_latest` policy).
- `recommended` — optional.
- `policy.mode` — `auto_latest`, `custom` or `age_based`. Unknown values are
  accepted and reported as `PolicyMode.unknown`.
- `policy.force_update` — when `false`, being below the minimum yields
  `updateAvailable`, never `updateRequired`.
- `policy.enabled` — defaults to `true`. `false` disables enforcement.
- `update.url` — the store page to open. When absent the plugin uses the
  platform store deep link for the package / configured App Store id.
- `server_time` — informational.

The server returns data, not a verdict. The client computes the final state.

## Error handling on the client

| Server behaviour | Client behaviour |
|---|---|
| non-2xx, timeout, connection error | Use cache; else `checkFailed` |
| invalid JSON / missing `latest` / newer schema | Same as above |
| `responseValidator` returns `false` | Same as above |

## Suggested server-side policy evaluation

```text
latest   = newest release with status=published for (app, platform, channel)
minimum  = switch policy.mode
             auto_latest → latest
             custom      → policy.custom_minimum_version / build
             age_based   → oldest published release younger than policy.max_age_days
```

Serve the last known good store data when a store API call fails; never
let a store outage cause a mass forced update.

## Admin endpoints (suggested, not used by the plugin)

```text
GET    /v1/admin/apps
GET    /v1/admin/releases
GET    /v1/admin/policies
PUT    /v1/admin/policies/{appId}
POST   /v1/admin/releases/sync
GET    /health
GET    /ready
```
