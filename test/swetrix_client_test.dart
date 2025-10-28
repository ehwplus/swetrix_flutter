import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swetrix_flutter/swetrix_flutter.dart';

void main() {
  group('Swetrix client', () {
    test('sends pageview with merged context and metadata', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = Swetrix(
        projectId: 'PID123',
        options: SwetrixOptions(
          apiUrl: Uri.parse('https://api.example.com/log'),
          defaultContext: const SwetrixContext(
            locale: 'en-US',
            metadata: {'plan': 'pro'},
          ),
          requestOptions: const SwetrixRequestOptions(userAgent: 'UA/1.0'),
        ),
        httpClient: mockClient,
      );

      await client.trackPageView(
        page: '/home',
        context: const SwetrixContext(
          referrer: 'https://ref.example',
          metadata: {'plan': 'enterprise', 'level': 2},
        ),
        metadata: const {'cta': 'signup'},
        performanceMetrics:
            const SwetrixPerformanceMetrics(dns: 5, response: 12),
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(capturedRequest.url.toString(), 'https://api.example.com/log/');
      expect(body['pid'], equals('PID123'));
      expect(body['pg'], equals('/home'));
      expect(body['lc'], equals('en-US'));
      expect(body['ref'], equals('https://ref.example'));
      expect(body['perf'], equals({'dns': 5, 'response': 12}));
      expect(body['meta'],
          equals({'plan': 'enterprise', 'level': '2', 'cta': 'signup'}));
      expect(capturedRequest.headers['User-Agent'], equals('UA/1.0'));

      await client.close();
    });

    test('sends custom event with metadata and validates name', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = Swetrix(
        projectId: 'PID123',
        httpClient: mockClient,
      );

      await client.trackEvent(
        'Signup_Success',
        page: '/pricing',
        unique: true,
        metadata: const {
          'plan': 'pro',
          'value': 9.99,
          'eligible': true,
          'missing': null
        },
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(
          capturedRequest.url.toString(), 'https://api.swetrix.com/log/custom');
      expect(body['ev'], equals('Signup_Success'));
      expect(body['unique'], isTrue);
      expect(
          body['meta'],
          equals({
            'plan': 'pro',
            'value': '9.99',
            'eligible': 'true',
            'missing': 'null'
          }));

      await client.close();
    });

    test('throws when event name is invalid', () async {
      final client = Swetrix(projectId: 'PID');
      expect(
        () => client.trackEvent('123 invalid'),
        throwsArgumentError,
      );
      await client.close();
    });

    test('merges request headers for heartbeat', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = Swetrix(
        projectId: 'PID',
        options: const SwetrixOptions(
          requestOptions: SwetrixRequestOptions(
            headers: {'X-Default': 'value'},
            userAgent: 'Default-UA',
            clientIpAddress: '203.0.113.1',
          ),
        ),
        httpClient: mockClient,
      );

      await client.sendHeartbeat(
        requestOptions: const SwetrixRequestOptions(
          headers: {'X-Override': 'yes'},
          userAgent: 'Override-UA',
        ),
      );

      expect(capturedRequest.headers['User-Agent'], equals('Override-UA'));
      expect(capturedRequest.headers['X-Client-IP-Address'],
          equals('203.0.113.1'));
      expect(capturedRequest.headers['X-Default'], equals('value'));
      expect(capturedRequest.headers['X-Override'], equals('yes'));

      await client.close();
    });

    test('throws SwetrixException on non-success status', () async {
      final client = Swetrix(
        projectId: 'PID',
        httpClient: MockClient((request) async {
          return http.Response('quota exceeded', 402);
        }),
      );

      await expectLater(
        client.trackPageView(page: '/home'),
        throwsA(isA<SwetrixException>()
            .having((e) => e.statusCode, 'status', 402)
            .having((e) => e.body, 'body', 'quota exceeded')),
      );

      await client.close();
    });
  });
}
