import 'dart:io';
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
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackPageView(page: '/home');
      await client.trackPageView(page: '/home');

      expect(requests.length, 2);
      final firstPayload = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final secondPayload =
          jsonDecode(requests[1].body) as Map<String, dynamic>;

      expect(firstPayload['profileId'], isNotNull);
      expect(secondPayload['profileId'], equals(firstPayload['profileId']));

      final firstUa = requests[0].headers['User-Agent'];
      final secondUa = requests[1].headers['User-Agent'];
      expect(firstUa, isNotNull);
      expect(
          requests[0].headers['X-Client-IP-Address'], equals('198.51.100.1'));
      expect(secondUa, isNotNull);
      expect(
          requests[1].headers['X-Client-IP-Address'], equals('198.51.100.1'));
      expect(firstUa, contains('com.example.app/1.2.3+42'));
      if (Platform.isMacOS) {
        expect(firstUa, contains('Mac OS X'));
      }

      final firstMeta = firstPayload['meta'] as Map<String, dynamic>;

      expect(secondPayload['profileId'], (x) => x != null);
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
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackEvent(
        'Purchase',
        metadata: const {'amount': 9.99, 'currency': 'USD'},
      );

      final payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      final meta = payload['meta'] as Map<String, dynamic>;

      expect(meta['currency'], equals('USD'));
      expect(capturedRequest!.headers['User-Agent'], isNotNull);
      expect(capturedRequest!.headers['User-Agent'],
          contains('com.example.app/1.2.3+42'));
      if (Platform.isMacOS) {
        expect(capturedRequest!.headers['User-Agent'], contains('Mac OS X'));
      }
      expect(capturedRequest!.headers['X-Client-IP-Address'],
          equals('198.51.100.1'));

      await client.close();
    });

    test('allows overriding profileId per tracking call', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PID789',
        options: SwetrixOptions(
          apiUrl: Uri.parse('https://api.example.com/log'),
          profileId: 'global-profile',
        ),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackEvent(
        'CheckoutStarted',
        profileId: 'override-profile',
      );

      final payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(payload['profileId'], isNotNull);

      await client.close();
    });

    test('evaluates feature flags with resolved profileId and caches results',
        () async {
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'flags': {'new_ui': true},
            'experiments': {'checkout-redesign': 'variant-b'},
          }),
          200,
        );
      });

      final client = SwetrixFlutterClient(
        projectId: 'PID999',
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      final flags = await client.getFeatureFlags();
      final experiments = await client.getExperiments();
      final flag = await client.getFeatureFlag('new_ui');
      final variant = await client.getExperiment('checkout-redesign');

      expect(flags, equals({'new_ui': true}));
      expect(experiments, equals({'checkout-redesign': 'variant-b'}));
      expect(flag, isTrue);
      expect(variant, equals('variant-b'));
      expect(requests, hasLength(1));

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['pid'], equals('PID999'));
      expect(body['profileId'], isNotNull);
      expect(
        requests.single.url.toString(),
        equals('https://api.example.com/feature-flag/evaluate'),
      );
      expect(requests.single.headers['User-Agent'], isNotNull);
      expect(
        requests.single.headers['X-Client-IP-Address'],
        equals('198.51.100.1'),
      );

      await client.close();
    });

    test('queues events while offline and flushes them after reconnect',
        () async {
      final requests = <http.Request>[];
      var offline = true;
      final mockClient = MockClient((request) async {
        if (offline) {
          throw http.ClientException('offline');
        }
        requests.add(request);
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PID555',
        options: const SwetrixOptions(
          queueFailedRequests: true,
          queueRetryInterval: Duration(milliseconds: 5),
        ),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackEvent('OfflineEvent');

      offline = false;
      await client.trackEvent('OnlineEvent');

      expect(requests, hasLength(2));
      final firstBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final secondBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(firstBody['ev'], equals('OfflineEvent'));
      expect(secondBody['ev'], equals('OnlineEvent'));

      await client.close();
    });
  });
}
