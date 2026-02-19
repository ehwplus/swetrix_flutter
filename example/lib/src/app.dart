import 'package:flutter/material.dart';
import 'package:swetrix_example/src/page.dart';
import 'package:swetrix_flutter/swetrix_flutter.dart';

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
