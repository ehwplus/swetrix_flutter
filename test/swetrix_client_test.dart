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
          profileId: 'profile-global',
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
      expect(capturedRequest.url.toString(), 'https://api.example.com/log');
      expect(body['pid'], equals('PID123'));
      expect(body['pg'], equals('/home'));
      expect(body['profileId'], equals('profile-global'));
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
        options: const SwetrixOptions(profileId: 'global-profile'),
        httpClient: mockClient,
      );

      await client.trackEvent(
        'Signup_Success',
        page: '/pricing',
        unique: true,
        profileId: 'event-profile',
        metadata: const {
          'plan': 'pro',
          'value': 9.99,
          'eligible': true,
          'missing': null
        },
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(capturedRequest.url.toString(),
          'https://api.swetrix.com/backend/log/custom');
      expect(body['ev'], equals('Signup_Success'));
      expect(body['unique'], isTrue);
      expect(body['profileId'], equals('event-profile'));
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

    test('merges context metadata into custom events', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      });

      final client = Swetrix(
        projectId: 'PID123',
        options: const SwetrixOptions(
          defaultContext: SwetrixContext(metadata: {'os': 'iOS'}),
        ),
        httpClient: mockClient,
      );

      await client.trackEvent(
        'Purchase',
        context: const SwetrixContext(metadata: {'plan': 'pro'}),
        metadata: const {'amount': 9.99},
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(
        body['meta'],
        equals({'os': 'iOS', 'plan': 'pro', 'amount': '9.99'}),
      );

      await client.close();
    });

    test('does not queue unique 403 responses', () async {
      const uniqueBody =
          'The event was not saved because it was not unique while unique only param is provided';
      final mockClient = MockClient((request) async {
        return http.Response(uniqueBody, 403);
      });

      final client = Swetrix(
        projectId: 'PID123',
        options: const SwetrixOptions(queueFailedRequests: true),
        httpClient: mockClient,
      );

      await expectLater(
        client.trackPageView(page: '/home', unique: true),
        throwsA(isA<Forbidden403NotUnique>()),
      );
      expect(client.pendingQueueLength, 0);

      await client.close();
    });

    test('swallows heartbeat-before-session 403 without queueing', () async {
      const heartbeatBody =
          'The heartbeat was not saved because there is no session for this request. Please, send a pageview or custom event request first to initialise the session.';
      final mockClient = MockClient((request) async {
        return http.Response(heartbeatBody, 403);
      });

      final client = Swetrix(
        projectId: 'PID123',
        options: const SwetrixOptions(queueFailedRequests: true),
        httpClient: mockClient,
      );

      await expectLater(client.sendHeartbeat(), completes);
      expect(client.pendingQueueLength, 0);

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
          profileId: 'heartbeat-profile',
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
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['profileId'], equals('heartbeat-profile'));

      await client.close();
    });

    test('fetches and caches feature flags and experiments', () async {
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'flags': {'new_checkout': true},
            'experiments': {'checkout-test': 'variant-a'},
          }),
          200,
        );
      });

      final client = Swetrix(
        projectId: 'PID123',
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
      );

      final flags = await client.getFeatureFlags(profileId: 'user-1');
      final experiments = await client.getExperiments(profileId: 'user-1');
      final singleFlag =
          await client.getFeatureFlag('new_checkout', profileId: 'user-1');

      expect(flags, equals({'new_checkout': true}));
      expect(experiments, equals({'checkout-test': 'variant-a'}));
      expect(singleFlag, isTrue);
      expect(requests, hasLength(1));
      expect(
        requests.single.url.toString(),
        'https://api.example.com/feature-flag/evaluate',
      );

      final requestBody =
          jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requestBody['pid'], equals('PID123'));
      expect(requestBody['profileId'], equals('user-1'));

      await client.getFeatureFlags(profileId: 'user-1', forceRefresh: true);
      expect(requests, hasLength(2));

      await client.close();
    });

    test('returns configured profile id without network call', () async {
      final client = Swetrix(
        projectId: 'PID123',
        options: const SwetrixOptions(profileId: 'configured-profile'),
        httpClient: MockClient((_) async {
          fail('Network should not be called when profileId is configured.');
        }),
      );

      final profileId = await client.getProfileId();
      expect(profileId, equals('configured-profile'));

      await client.close();
    });

    test('fetches profile and session ids from API', () async {
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/log/profile-id') {
          return http.Response(jsonEncode({'profileId': 'api-profile'}), 200);
        }
        if (request.url.path == '/log/session-id') {
          return http.Response(jsonEncode({'sessionId': 'api-session'}), 200);
        }
        return http.Response('not found', 404);
      });

      final client = Swetrix(
        projectId: 'PID123',
        options:
            SwetrixOptions(apiUrl: Uri.parse('https://api.example.com/log')),
        httpClient: mockClient,
      );

      final profileId = await client.getProfileId();
      final sessionId = await client.getSessionId();

      expect(profileId, equals('api-profile'));
      expect(sessionId, equals('api-session'));
      expect(requests, hasLength(2));
      expect(
          requests[0].url.toString(), 'https://api.example.com/log/profile-id');
      expect(
          requests[1].url.toString(), 'https://api.example.com/log/session-id');

      await client.close();
    });

    test('queues failed requests and flushes on next successful call',
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

      final client = Swetrix(
        projectId: 'PID123',
        options: const SwetrixOptions(
          queueFailedRequests: true,
          maxQueueSize: 10,
          queueRetryInterval: Duration(milliseconds: 5),
        ),
        httpClient: mockClient,
      );

      await client.trackEvent('WhileOffline');
      expect(client.pendingQueueLength, equals(1));

      offline = false;
      await client.trackEvent('AfterReconnect');

      expect(client.pendingQueueLength, equals(0));
      expect(requests, hasLength(2));
      final firstBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final secondBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(firstBody['ev'], equals('WhileOffline'));
      expect(secondBody['ev'], equals('AfterReconnect'));

      await client.close();
    });

    test('does not queue when queueing is disabled', () async {
      final client = Swetrix(
        projectId: 'PID123',
        options: const SwetrixOptions(queueFailedRequests: false),
        httpClient: MockClient((_) async {
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        client.trackEvent('WillFail'),
        throwsA(isA<http.ClientException>()),
      );
      expect(client.pendingQueueLength, equals(0));

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
