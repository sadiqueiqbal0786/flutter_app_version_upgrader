# flutter_app_version_upgrader example

Demonstrates the plugin's built-in UI (`package:flutter_app_version_upgrader/ui.dart`)
wrapped around a host app: a blocking page for `updateRequired`, a bottom
sheet with Update / Later / Skip for `updateAvailable`, and a fail-open path
when the version service is unreachable. The home page shows the raw result.

## Run it

1. Start the mock version API from this directory:

   ```sh
   dart run tool/mock_version_server.dart --mode custom --latest 2.7.0:270 --minimum 2.5.0:250
   ```

   Pass `--mode auto_latest` to make the minimum follow the latest release,
   or `--no-force` to turn a required update into a soft one.

2. Run the app on an emulator or simulator:

   ```sh
   flutter run
   ```

   The example's own version is `1.0.0+1`, so with the defaults above it
   shows the force-update screen. Change the mock server's `--minimum` to
   `1.0.0:1` to see the "update available" path instead.

3. Integration tests (device or emulator required):

   ```sh
   flutter test integration_test/plugin_integration_test.dart
   ```
