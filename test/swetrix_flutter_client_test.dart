import 'dart:async';
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
      expect(firstPayload['unique'], isTrue);
      expect(secondPayload.containsKey('unique'), isFalse);

      await client.trackPageView(
        page: '/settings',
        metadata: const {'screenClass': 'SettingsScreen'},
      );
      expect(requests.length, 3);
      final thirdPayload = jsonDecode(requests[2].body) as Map<String, dynamic>;
      final thirdMeta = thirdPayload['meta'] as Map<String, dynamic>;
      expect(thirdMeta['screenClass'], equals('SettingsScreen'));
      expect(thirdMeta['app_version'], equals('1.2.3'));

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
      expect(meta['app_version'], equals('1.2.3'));
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
      expect(payload['profileId'], equals('override-profile'));

      await client.close();
    });

    test('honours profileId override on pageviews', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PIDPV',
        options: SwetrixOptions(
          apiUrl: Uri.parse('https://api.example.com/log'),
          profileId: 'global-profile',
        ),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackPageView(page: '/home', profileId: 'override-profile');

      final payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(payload['profileId'], equals('override-profile'));

      await client.close();
    });

    test('keeps caller error metadata when decorating errors', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PIDERR',
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackError(
        const SwetrixErrorEvent(
          name: 'StateError',
          message: 'bad',
          metadata: {'code': 'E42'},
        ),
      );

      final payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      final meta = payload['meta'] as Map<String, dynamic>;
      expect(meta['code'], equals('E42'));
      expect(meta['app_version'], equals('1.2.3'));

      await client.close();
    });

    test('swallows unique 403 on first pageview and does not retry unique',
        () async {
      const uniqueBody =
          'The event was not saved because it was not unique while unique only param is provided';
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(uniqueBody, 403);
        }
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PID403',
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackPageView(page: '/home');
      await client.trackPageView(page: '/home');

      expect(requests, hasLength(2));
      final first = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final second = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(first['unique'], isTrue);
      expect(second.containsKey('unique'), isFalse);
      expect(client.pendingQueueLength, 0);

      await client.close();
    });

    test('heartbeat includes resolved IP and user agent headers', () async {
      final heartbeatStarted = Completer<http.Request>();
      var pageViews = 0;
      final mockClient = MockClient((request) async {
        if (pageViews == 0) {
          pageViews++;
          return http.Response('{}', 201);
        }
        if (!heartbeatStarted.isCompleted) {
          heartbeatStarted.complete(request);
        }
        return http.Response('{}', 201);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PIDHB',
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      await client.trackPageView(page: '/home');
      client.startHeartbeat(interval: const Duration(hours: 1));
      final heartbeatRequest = await heartbeatStarted.future.timeout(
        const Duration(seconds: 2),
      );

      expect(
        heartbeatRequest.headers['X-Client-IP-Address'],
        equals('198.51.100.1'),
      );
      expect(heartbeatRequest.headers['User-Agent'], isNotNull);

      await client.close();
    });

    test('startHeartbeat swallows heartbeat-before-session 403', () async {
      const heartbeatBody =
          'The heartbeat was not saved because there is no session for this request. Please, send a pageview or custom event request first to initialise the session.';
      final mockClient = MockClient((request) async {
        return http.Response(heartbeatBody, 403);
      });

      final client = SwetrixFlutterClient(
        projectId: 'PIDHB403',
        options: const SwetrixOptions(queueFailedRequests: true),
        httpClient: mockClient,
        clientIpResolver: () async => '198.51.100.1',
      );

      client.startHeartbeat(interval: const Duration(hours: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(client.pendingQueueLength, 0);

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
