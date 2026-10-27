import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_version_upgrader/flutter_app_version_upgrader.dart';
import 'package:flutter_app_version_upgrader/ui.dart';

/// Base URL of the version API.
///
/// Run `dart run tool/mock_version_server.dart` from the `example/`
/// directory to get a local backend. The Android emulator reaches the host
/// machine at 10.0.2.2; the iOS simulator uses localhost.
String get defaultBaseUrl => Platform.isAndroid
    ? 'http://10.0.2.2:8080'
    : 'http://localhost:8080';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VersionManager.initialize(
    VersionManagerConfig(
      baseUrl: defaultBaseUrl,
      channel: VersionChannel.production,
      timeout: const Duration(seconds: 5),
      logger: (message, [error]) => debugPrint('[version] $message $error'),
    ),
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Version upgrader example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // The plugin's built-in UI: a blocking page for required updates and
      // a bottom sheet with Update / Later / Skip for optional ones. Swap
      // `style`, `texts` or the builders to make it your own; see README.
      builder: (context, child) => VersionUpgrader(
        style: const UpgraderStyle(presentation: UpgraderPresentation.bottomSheet),
        texts: const UpgraderTexts(availableTitle: 'New version available'),
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  VersionCheckResult? _result;
  bool _busy = false;
  StreamSubscription<VersionCheckResult>? _subscription;

  @override
  void initState() {
    super.initState();
    _result = VersionManager.instance.lastResult;
    _subscription = VersionManager.instance.results.listen((r) {
      if (mounted) setState(() => _result = r);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _run({bool preferCache = false}) async {
    setState(() => _busy = true);
    try {
      await VersionManager.check(preferCache: preferCache);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Version upgrader')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (result == null)
            const ListTile(title: Text('No check has run yet.'))
          else ...[
            _StatusBanner(result: result),
            const SizedBox(height: 16),
            _Row('Status', result.status.name),
            _Row('Source', '${result.source.name}${result.isStale ? ' (stale)' : ''}'),
            _Row('Installed', '${result.current}'),
            _Row('Latest', '${result.latest ?? '-'}'),
            _Row('Minimum', '${result.minimum ?? '-'}'),
            _Row('Recommended', '${result.recommended ?? '-'}'),
            _Row('Policy', result.policy?.toString() ?? '-'),
            _Row('Update URL', result.updateUrl ?? '-'),
            _Row('Message', result.updateMessage ?? '-'),
            _Row('Checked at', result.checkedAt.toIso8601String()),
            if (result.error != null) _Row('Error', '${result.error}'),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _run(),
                icon: const Icon(Icons.refresh),
                label: const Text('Check (network)'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(preferCache: true),
                icon: const Icon(Icons.cached),
                label: const Text('Check (prefer cache)'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : VersionManager.clearCache,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear cache'),
              ),
              if (result != null && result.isUpdateAvailable)
                FilledButton.tonalIcon(
                  onPressed: () => VersionManager.openStore(result),
                  icon: const Icon(Icons.storefront),
                  label: const Text('Open store'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.result});

  final VersionCheckResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (result.status) {
      UpdateStatus.upToDate => (Icons.check_circle, 'Up to date', scheme.primary),
      UpdateStatus.updateAvailable =>
        (Icons.new_releases, 'Update available', scheme.tertiary),
      UpdateStatus.updateRequired =>
        (Icons.error, 'Update required', scheme.error),
      UpdateStatus.checkFailed =>
        (Icons.cloud_off, 'Check failed', scheme.outline),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: Text('Installed ${result.current}'),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
