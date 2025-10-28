import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swetrix_flutter/swetrix_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'ExampleApp',
      packageName: 'com.example.app',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
      installerStore: null,
    );
  });

  group('SwetrixFlutterClient', () {
    test('enriches pageview metadata and ensures unique only once', () async {
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PID123',
        options: SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        userAgent: 'TestAgent/1.0',
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackPageView(page: '/home');
      await client.trackPageView(page: '/home');

      expect(requests.length, 2);
      final firstPayload = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final secondPayload = jsonDecode(requests[1].body) as Map<String, dynamic>;

      expect(firstPayload['unique'], isTrue);
      expect(secondPayload.containsKey('unique'), isFalse);

      expect(requests[0].headers['User-Agent'], equals('TestAgent/1.0'));
      expect(requests[0].headers['X-Client-IP-Address'], equals('198.51.100.1'));
      expect(requests[1].headers['User-Agent'], equals('TestAgent/1.0'));
      expect(requests[1].headers['X-Client-IP-Address'], equals('198.51.100.1'));

      final firstMeta = firstPayload['meta'] as Map<String, dynamic>;
      final secondMeta = secondPayload['meta'] as Map<String, dynamic>;

      expect(firstMeta['visitor_id'], isNotEmpty);
      expect(firstMeta['visitor_id'], equals(secondMeta['visitor_id']));
      expect(firstMeta['app_version'], equals('1.2.3'));
      expect(firstMeta['os'], isNotNull);

      await client.close();
    });

    test('adds visitor metadata for custom events', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PID456',
        options: SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        userAgent: 'TestAgent/1.0',
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackEvent(
        'Purchase',
        metadata: const {'amount': 9.99, 'currency': 'USD'},
      );

      final payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      final meta = payload['meta'] as Map<String, dynamic>;

      expect(meta['visitor_id'], isNotEmpty);
      expect(meta['currency'], equals('USD'));
      expect(meta['os'], isNotEmpty);
      expect(capturedRequest!.headers['User-Agent'], equals('TestAgent/1.0'));
      expect(capturedRequest!.headers['X-Client-IP-Address'], equals('198.51.100.1'));

      await client.close();
    });
  });
}
