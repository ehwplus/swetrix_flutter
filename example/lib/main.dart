import 'package:flutter/material.dart';
import 'package:swetrix_example/src/app.dart';
import 'package:swetrix_flutter/swetrix_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final client = SwetrixFlutterClient(
    projectId: 'KwBjnEj5H3YK', // put 'YOUR_PROJECT_ID' here
    clientIpResolver: () async => '203.0.113.42',
    options: SwetrixOptions(
      apiUrl: Uri.parse('https://analytics.ehwplus.com/backend/log'),
      profileId: 'user_42',
    ),
  );
  runApp(SwetrixExampleApp(client: client));
}
