import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swetrix/swetrix.dart';

void main() {
  runApp(const SwetrixExampleApp());
}

class SwetrixExampleApp extends StatelessWidget {
  const SwetrixExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swetrix Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AnalyticsDemoPage(),
    );
  }
}

class AnalyticsDemoPage extends StatefulWidget {
  const AnalyticsDemoPage({super.key});

  @override
  State<AnalyticsDemoPage> createState() => _AnalyticsDemoPageState();
}

class _AnalyticsDemoPageState extends State<AnalyticsDemoPage> {
  late final Swetrix _swetrix;
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();

    _swetrix = Swetrix(
      projectId: 'YOUR_PROJECT_ID',
      options: const SwetrixOptions(
        defaultContext: SwetrixContext(locale: 'en-US'),
        requestOptions: SwetrixRequestOptions(
          userAgent: 'SwetrixExample/1.0.0',
          // Replace with the visitor's IP if available (see docs).
          clientIpAddress: '203.0.113.42',
        ),
      ),
    );

    unawaited(_swetrix.trackPageView(page: '/example/home'));
    _swetrix.startHeartbeat();
  }

  @override
  void dispose() {
    _swetrix.stopHeartbeat();
    _swetrix.close();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    await _swetrix.trackEvent(
      'SignupAttempt',
      page: '/example/home',
      metadata: const {'plan': 'pro', 'fromExample': true},
    );
    _log('Tracked custom event: SignupAttempt');
  }

  Future<void> _handleError() async {
    await _swetrix.trackError(
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
              'Project ID: ${_swetrix.projectId}',
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
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
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
