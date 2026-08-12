import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:swetrix_flutter/src/exceptions/forbidden_403_not_unique.dart';

import 'context/swetrix_context.dart';
import 'error_event.dart';
import 'exceptions/forbidden_403_heartbeat_sent_before_event.dart';
import 'options.dart';
import 'performance_metrics.dart';
import 'request_options.dart';
import 'exceptions/swetrix_exception.dart';

/// Low-level client for interacting with the Swetrix Events API if you want to do all Flutter things yourself.
class Swetrix {
  Swetrix({
    required this.projectId,
    SwetrixOptions options = const SwetrixOptions(),
    http.Client? httpClient,
  })  : _options = options,
        _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _baseUrl = _normaliseBase(_resolveBase(options.apiUrl)),
        _apiBaseUrl =
            _normaliseApiBase(_resolveApiBase(_resolveBase(options.apiUrl)));

  final String projectId;
  final http.Client _client;
  final bool _ownsClient;
  SwetrixOptions _options;
  Uri _baseUrl;
  Uri _apiBaseUrl;
  Timer? _heartbeatTimer;
  SwetrixRequestOptions? _heartbeatRequestOptions;
  String? _heartbeatProfileId;
  Timer? _queueRetryTimer;
  bool _isFlushingQueue = false;
  final ListQueue<_SwetrixQueuedRequest> _requestQueue =
      ListQueue<_SwetrixQueuedRequest>();
  _SwetrixFeatureCache? _featureCache;

  static final Uri _defaultApiUrl =
      Uri.parse('https://api.swetrix.com/backend/log');
  static const Duration _defaultFeatureCacheDuration = Duration(minutes: 5);

  SwetrixOptions get options => _options;

  set options(SwetrixOptions value) {
    _options = value;
    _baseUrl = _normaliseBase(_resolveBase(value.apiUrl));
    _apiBaseUrl =
        _normaliseApiBase(_resolveApiBase(_resolveBase(value.apiUrl)));
    _featureCache = null;
  }

  /// Sends a pageview event to Swetrix.
  Future<void> trackPageView({
    String? page,
    bool unique = false,
    String? profileId,
    String? locale,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixPerformanceMetrics? performanceMetrics,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final effectiveProfileId = profileId ?? _options.profileId;
    final effectiveContext = _mergeContext(context);
    final payload = <String, Object?>{
      'pid': projectId,
      if (page != null) 'pg': page,
      if (locale != null) 'lc': locale,
      if (unique) 'unique': true,
      if (effectiveProfileId != null) 'profileId': effectiveProfileId,
    };

    Map<String, Object?>? mergedMetadata = metadata;
    if (effectiveContext != null) {
      payload.addAll(effectiveContext.toPayload());
      mergedMetadata =
          _mergeMetadata(effectiveContext.toPageMetadata(), mergedMetadata);
    }

    if (mergedMetadata != null && mergedMetadata.isNotEmpty) {
      payload['meta'] = _serialiseMeta(mergedMetadata);
    }

    final perfPayload = performanceMetrics?.toPayload();
    if (perfPayload != null && perfPayload.isNotEmpty) {
      payload['perf'] = perfPayload;
    }

    await _post('', payload, requestOptions: requestOptions);
  }

  /// Sends a custom event to Swetrix.
  Future<void> trackEvent(
    String eventName, {
    bool unique = false,
    String? page,
    String? profileId,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    String? locale,
    SwetrixRequestOptions? requestOptions,
  }) async {
    _validateEventName(eventName);

    final effectiveProfileId = profileId ?? _options.profileId;
    final effectiveContext = _mergeContext(context);
    final payload = <String, Object?>{
      'pid': projectId,
      'ev': eventName,
      if (locale != null) 'lc': locale,
      if (unique) 'unique': true,
      if (page != null) 'pg': page,
      if (effectiveProfileId != null) 'profileId': effectiveProfileId,
    };

    Map<String, Object?>? mergedMetadata = metadata;
    if (effectiveContext != null) {
      payload.addAll(effectiveContext.toPayload());
      mergedMetadata =
          _mergeMetadata(effectiveContext.toPageMetadata(), mergedMetadata);
    }

    if (mergedMetadata != null && mergedMetadata.isNotEmpty) {
      payload['meta'] = _serialiseMeta(mergedMetadata);
    }

    await _post('custom', payload, requestOptions: requestOptions);
  }

  /// Sends an error event to Swetrix.
  Future<void> trackError(
    SwetrixErrorEvent error, {
    SwetrixContext? context,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final effectiveContext = _mergeContext(context);
    final payload = <String, Object?>{
      'pid': projectId,
      ...error.toPayload(),
    };

    if (effectiveContext != null) {
      final contextPayload = effectiveContext.toPayload();
      for (final entry in contextPayload.entries) {
        payload.putIfAbsent(entry.key, () => entry.value);
      }
      payload.removeWhere((key, value) => value == null);
    }

    final meta = error.metadata;
    if (meta != null && meta.isNotEmpty) {
      payload['meta'] = _serialiseMeta(meta);
    }

    await _post('error', payload, requestOptions: requestOptions);
  }

  /// Sends a heartbeat event to Swetrix.
  Future<void> sendHeartbeat({
    String? profileId,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final effectiveProfileId = profileId ?? _options.profileId;
    final payload = <String, Object?>{
      'pid': projectId,
      if (effectiveProfileId != null) 'profileId': effectiveProfileId,
    };
    await _post('hb', payload, requestOptions: requestOptions);
  }

  /// Fetches all feature flags for the current project.
  Future<Map<String, bool>> getFeatureFlags({
    String? profileId,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final effectiveProfileId = profileId ?? _options.profileId;
    final cache = _featureCache;

    if (!forceRefresh &&
        cache != null &&
        cache.profileId == effectiveProfileId &&
        DateTime.now().difference(cache.timestamp) <
            _defaultFeatureCacheDuration) {
      return cache.flags;
    }

    try {
      await _fetchFlagsAndExperiments(
        profileId: effectiveProfileId,
        requestOptions: requestOptions,
      );
    } catch (_) {
      // Return cached values (if available) on fetch failures.
    }

    return _featureCache?.flags ?? const <String, bool>{};
  }

  /// Fetches a single feature flag value.
  Future<bool> getFeatureFlag(
    String key, {
    String? profileId,
    bool defaultValue = false,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final flags = await getFeatureFlags(
      profileId: profileId,
      forceRefresh: forceRefresh,
      requestOptions: requestOptions,
    );
    return flags[key] ?? defaultValue;
  }

  /// Clears the feature flag and experiments cache.
  void clearFeatureFlagsCache() {
    _featureCache = null;
  }

  /// Fetches all experiment assignments for the current project.
  Future<Map<String, String>> getExperiments({
    String? profileId,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final effectiveProfileId = profileId ?? _options.profileId;
    final cache = _featureCache;

    if (!forceRefresh &&
        cache != null &&
        cache.profileId == effectiveProfileId &&
        DateTime.now().difference(cache.timestamp) <
            _defaultFeatureCacheDuration) {
      return cache.experiments;
    }

    try {
      await _fetchFlagsAndExperiments(
        profileId: effectiveProfileId,
        requestOptions: requestOptions,
      );
    } catch (_) {
      // Return cached values (if available) on fetch failures.
    }

    return _featureCache?.experiments ?? const <String, String>{};
  }

  /// Fetches a single experiment variant assignment.
  Future<String?> getExperiment(
    String experimentId, {
    String? profileId,
    String? defaultVariant,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final experiments = await getExperiments(
      profileId: profileId,
      forceRefresh: forceRefresh,
      requestOptions: requestOptions,
    );
    return experiments[experimentId] ?? defaultVariant;
  }

  /// Alias for [clearFeatureFlagsCache].
  void clearExperimentsCache() {
    clearFeatureFlagsCache();
  }

  /// Number of requests currently queued for retry.
  int get pendingQueueLength => _requestQueue.length;

  /// Tries to send all currently queued requests immediately.
  Future<void> flushQueue() => _flushQueue();

  /// Retrieves the profile id assigned to this user.
  Future<String?> getProfileId({
    SwetrixRequestOptions? requestOptions,
  }) async {
    final configuredProfileId = _options.profileId;
    if (configuredProfileId != null && configuredProfileId.isNotEmpty) {
      return configuredProfileId;
    }

    try {
      final response = await _postForJson(
        _apiBaseUrl.resolve('log/profile-id'),
        <String, Object?>{'pid': projectId},
        requestOptions: requestOptions,
        throwOnHttpError: false,
      );

      final profileId = response?['profileId'];
      if (profileId is String && profileId.isNotEmpty) {
        return profileId;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Retrieves the current session id.
  Future<String?> getSessionId({
    SwetrixRequestOptions? requestOptions,
  }) async {
    try {
      final response = await _postForJson(
        _apiBaseUrl.resolve('log/session-id'),
        <String, Object?>{'pid': projectId},
        requestOptions: requestOptions,
        throwOnHttpError: false,
      );

      final sessionId = response?['sessionId'];
      if (sessionId is String && sessionId.isNotEmpty) {
        return sessionId;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Starts periodically sending heartbeat events.
  void startHeartbeat({
    Duration interval = const Duration(seconds: 30),
    String? profileId,
    SwetrixRequestOptions? requestOptions,
  }) {
    stopHeartbeat();
    if (_options.disabled) {
      return;
    }
    _heartbeatRequestOptions = requestOptions;
    _heartbeatProfileId = profileId;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      unawaited(sendHeartbeat(
        profileId: _heartbeatProfileId,
        requestOptions: _heartbeatRequestOptions,
      ));
    });
    unawaited(sendHeartbeat(
      profileId: profileId,
      requestOptions: requestOptions,
    ));
  }

  /// Stops automatic heartbeat requests.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatRequestOptions = null;
    _heartbeatProfileId = null;
  }

  /// Disposes the underlying HTTP client.
  Future<void> close() async {
    stopHeartbeat();
    _queueRetryTimer?.cancel();
    _queueRetryTimer = null;
    if (_ownsClient) {
      _client.close();
    }
  }

  SwetrixContext? _mergeContext(SwetrixContext? context) {
    final defaultContext = _options.defaultContext;
    if (defaultContext == null) {
      return context;
    }
    return defaultContext.merge(context);
  }

  Future<void> _post(
    String path,
    Map<String, Object?> payload, {
    SwetrixRequestOptions? requestOptions,
  }) async {
    if (_options.disabled) {
      return;
    }

    if (_requestQueue.isNotEmpty) {
      await _flushQueue();
    }

    final uri = _resolve(path);
    try {
      final response =
          await _send(uri, payload, requestOptions: requestOptions);
      final statusCode = response.statusCode;
      if (statusCode == 403) {
        if (response.body.contains(
            'The heartbeat was not saved because there is no session for this request. Please, send a pageview or custom event request first to initialise the session.')) {
          throw Forbidden403HeartbeatSentBeforeEvent(response.body);
        }
        if (response.body.contains(
            'The event was not saved because it was not unique while unique only param is provided')) {
          // This error is usually returned when the unique parameter is set to true and the event is not unique,
          // i.e. the pageview event has already been recorded for this session.
          throw Forbidden403NotUnique(response.body);
        }
      } else if (statusCode >= 400) {
        final exception = SwetrixException(
          'Request to ${uri.path} failed',
          statusCode: statusCode,
          body: response.body,
        );
        if (_shouldQueueStatusCode(statusCode)) {
          _enqueueRequest(path, payload, requestOptions);
          _scheduleQueueRetry();
          return;
        }
        throw exception;
      }
    } catch (error) {
      if (_shouldQueueError(error)) {
        _enqueueRequest(path, payload, requestOptions);
        _scheduleQueueRetry();
        return;
      }
      rethrow;
    }
  }

  Future<void> _flushQueue() async {
    if (_options.disabled || _isFlushingQueue || _requestQueue.isEmpty) {
      return;
    }

    _queueRetryTimer?.cancel();
    _queueRetryTimer = null;

    _isFlushingQueue = true;
    try {
      while (_requestQueue.isNotEmpty) {
        final queued = _requestQueue.first;
        final uri = _resolve(queued.path);
        try {
          final response = await _send(
            uri,
            queued.payload,
            requestOptions: queued.requestOptions,
          );

          if (response.statusCode >= 400) {
            if (_shouldQueueStatusCode(response.statusCode)) {
              _scheduleQueueRetry();
              return;
            }

            // Unrecoverable request: drop it so it does not block the queue.
            _requestQueue.removeFirst();
            continue;
          }

          _requestQueue.removeFirst();
        } catch (_) {
          _scheduleQueueRetry();
          return;
        }
      }
    } finally {
      _isFlushingQueue = false;
    }
  }

  void _enqueueRequest(
    String path,
    Map<String, Object?> payload,
    SwetrixRequestOptions? requestOptions,
  ) {
    if (!_options.queueFailedRequests) {
      return;
    }

    final maxQueueSize = _options.maxQueueSize;
    if (maxQueueSize <= 0) {
      return;
    }

    while (_requestQueue.length >= maxQueueSize) {
      _requestQueue.removeFirst();
    }

    _requestQueue.addLast(
      _SwetrixQueuedRequest(
        path: path,
        payload: _stripNulls(payload),
        requestOptions: requestOptions,
      ),
    );
  }

  void _scheduleQueueRetry() {
    if (_options.disabled || _requestQueue.isEmpty) {
      return;
    }
    if (_queueRetryTimer != null) {
      return;
    }
    final retryInterval = _options.queueRetryInterval;
    _queueRetryTimer = Timer(retryInterval, () {
      _queueRetryTimer = null;
      unawaited(_flushQueue());
    });
  }

  bool _shouldQueueStatusCode(int statusCode) {
    if (!_options.queueFailedRequests) {
      return false;
    }
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  bool _shouldQueueError(Object error) {
    if (!_options.queueFailedRequests) {
      return false;
    }
    if (error is SwetrixException ||
        error is Forbidden403NotUnique ||
        error is Forbidden403HeartbeatSentBeforeEvent) {
      return false;
    }
    return true;
  }

  Future<http.Response> _send(
    Uri uri,
    Map<String, Object?> payload, {
    SwetrixRequestOptions? requestOptions,
  }) {
    final effectiveRequestOptions =
        _options.requestOptions.merge(requestOptions);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...effectiveRequestOptions.headers,
      if (effectiveRequestOptions.userAgent != null)
        'User-Agent': effectiveRequestOptions.userAgent!,
      if (effectiveRequestOptions.clientIpAddress != null)
        'X-Client-IP-Address': effectiveRequestOptions.clientIpAddress!,
    };

    return _client.post(
      uri,
      headers: headers,
      body: jsonEncode(_stripNulls(payload)),
    );
  }

  Future<Map<String, Object?>?> _postForJson(
    Uri uri,
    Map<String, Object?> payload, {
    SwetrixRequestOptions? requestOptions,
    bool throwOnHttpError = true,
  }) async {
    if (_options.disabled) {
      return null;
    }

    final response = await _send(uri, payload, requestOptions: requestOptions);
    if (response.statusCode >= 400) {
      if (throwOnHttpError) {
        throw SwetrixException(
          'Request to ${uri.path} failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }
      return null;
    }

    if (response.body.isEmpty) {
      return const <String, Object?>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const <String, Object?>{};
    }

    final result = <String, Object?>{};
    decoded.forEach((key, value) {
      result[key.toString()] = value;
    });
    return result;
  }

  Future<void> _fetchFlagsAndExperiments({
    String? profileId,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final body = <String, Object?>{
      'pid': projectId,
      if (profileId != null) 'profileId': profileId,
    };

    final json = await _postForJson(
      _apiBaseUrl.resolve('feature-flag/evaluate'),
      body,
      requestOptions: requestOptions,
      throwOnHttpError: false,
    );
    if (json == null) {
      return;
    }

    _featureCache = _SwetrixFeatureCache(
      flags: _parseBooleanMap(json['flags']),
      experiments: _parseStringMap(json['experiments']),
      timestamp: DateTime.now(),
      profileId: profileId,
    );
  }

  Uri _resolve(String path) {
    if (path.isEmpty) {
      return _baseUrl;
    }
    return _baseUrl.replace(path: '${_baseUrl.path}/$path');
  }

  static Uri _resolveBase(Uri? url) => url ?? _defaultApiUrl;

  static Uri _resolveApiBase(Uri logUrl) {
    var segments = List<String>.from(logUrl.pathSegments);
    if (segments.isNotEmpty && segments.last.isEmpty) {
      segments = segments.sublist(0, segments.length - 1);
    }
    if (segments.isNotEmpty && segments.last == 'log') {
      segments = segments.sublist(0, segments.length - 1);
    }
    return logUrl.replace(
      pathSegments: segments,
      query: null,
      fragment: null,
    );
  }

  static Uri _normaliseBase(Uri url) {
    if (url.path.isEmpty || !url.path.endsWith('/')) {
      return url;
    }
    return url.replace(path: url.path.substring(0, url.path.length - 1));
  }

  static Uri _normaliseApiBase(Uri url) {
    if (url.path.isEmpty || url.path.endsWith('/')) {
      return url;
    }
    return url.replace(path: '${url.path}/');
  }

  Map<String, Object?> _stripNulls(Map<String, Object?> original) {
    final result = <String, Object?>{};
    for (final entry in original.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is Map<String, Object?>) {
        final nested = _stripNulls(value);
        if (nested.isNotEmpty) {
          result[entry.key] = nested;
        }
      } else if (value is Map<String, String>) {
        final nested =
            value.map((key, nestedValue) => MapEntry(key, nestedValue));
        if (nested.isNotEmpty) {
          result[entry.key] = nested;
        }
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  Map<String, Object?>? _mergeMetadata(
    Map<String, Object?>? base,
    Map<String, Object?>? overlay,
  ) {
    if (overlay == null) {
      return base;
    }
    final result =
        base == null ? <String, Object?>{} : Map<String, Object?>.from(base);
    overlay.forEach((key, value) {
      result[key] = value;
    });
    return result;
  }

  Map<String, String> _serialiseMeta(Map<String, Object?> meta) {
    if (meta.length > 100) {
      throw ArgumentError.value(meta.length, 'meta.length',
          'Metadata cannot contain more than 100 keys.');
    }
    var totalLength = 0;
    final result = <String, String>{};
    meta.forEach((key, value) {
      if (value != null &&
          value is! String &&
          value is! num &&
          value is! bool) {
        throw ArgumentError.value(
            value, 'meta[$key]', 'Metadata values must be primitive types.');
      }
      final stringValue = value == null ? 'null' : value.toString();
      totalLength += key.length + stringValue.length;
      if (totalLength > 2000) {
        throw ArgumentError(
            'Combined metadata length cannot exceed 2000 characters.');
      }
      result[key] = stringValue;
    });
    return result;
  }

  Map<String, bool> _parseBooleanMap(Object? raw) {
    if (raw is! Map) {
      return const <String, bool>{};
    }
    final result = <String, bool>{};
    raw.forEach((key, value) {
      if (value is bool) {
        result[key.toString()] = value;
      }
    });
    return result;
  }

  Map<String, String> _parseStringMap(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (value is String) {
        result[key.toString()] = value;
      }
    });
    return result;
  }

  void _validateEventName(String eventName) {
    const pattern = r'^[A-Za-z][A-Za-z0-9_.]{0,63}$';
    if (!RegExp(pattern).hasMatch(eventName)) {
      throw ArgumentError.value(
        eventName,
        'eventName',
        'Event names must start with a letter and only contain letters, numbers, underscores and dots (max 64 characters).',
      );
    }
  }
}

class _SwetrixFeatureCache {
  const _SwetrixFeatureCache({
    required this.flags,
    required this.experiments,
    required this.timestamp,
    required this.profileId,
  });

  final Map<String, bool> flags;
  final Map<String, String> experiments;
  final DateTime timestamp;
  final String? profileId;
}

class _SwetrixQueuedRequest {
  const _SwetrixQueuedRequest({
    required this.path,
    required this.payload,
    required this.requestOptions,
  });

  final String path;
  final Map<String, Object?> payload;
  final SwetrixRequestOptions? requestOptions;
}
