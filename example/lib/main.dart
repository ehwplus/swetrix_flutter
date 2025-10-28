import 'package:flutter/material.dart';
import 'package:swetrix_flutter/swetrix_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final client = SwetrixFlutterClient(
    projectId: 'YOUR_PROJECT_ID',
    userAgent: 'SwetrixExample/1.0.0',
    clientIpResolver: () async => '203.0.113.42',
  );
  runApp(SwetrixExampleApp(client: client));
}

class SwetrixExampleApp extends StatelessWidget {
  const SwetrixExampleApp({required this.client, super.key});

  final SwetrixFlutterClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swetrix Demo',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: AnalyticsDemoPage(client: client),
    );
  }
}

class AnalyticsDemoPage extends StatefulWidget {
  const AnalyticsDemoPage({required this.client, super.key});

  final SwetrixFlutterClient client;

  @override
  State<AnalyticsDemoPage> createState() => _AnalyticsDemoPageState();
}

class _AnalyticsDemoPageState extends State<AnalyticsDemoPage> {
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();
    widget.client.startHeartbeat();
    widget.client
        .trackPageView(page: '/example/home')
        .then((_) => _log('Tracked initial page view'));
  }

  @override
  void dispose() {
    widget.client.stopHeartbeat();
    widget.client.close();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    await widget.client.trackEvent(
      'SignupAttempt',
      page: '/example/home',
      metadata: const {'plan': 'pro', 'fromExample': true},
    );
    _log('Tracked custom event: SignupAttempt');
  }

  Future<void> _handleError() async {
    await widget.client.trackError(
      const SwetrixErrorEvent(
        name: 'ExampleError',
        message: 'Demonstration error triggered by the UI.',
        page: '/example/home',
      ),
    );
    _log('Tracked error event');
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swetrix integration demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Project ID: ${widget.client.projectId}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _handleSignup,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Track custom event'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _handleError,
              icon: const Icon(Icons.warning_amber),
              label: const Text('Track error'),
            ),
            const SizedBox(height: 24),
            Text(
              'Log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: _logs.isEmpty
                    ? const Center(child: Text('No events sent yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (_, index) => Text(_logs[index]),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: _logs.length,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
