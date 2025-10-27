import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'context.dart';
import 'error_event.dart';
import 'options.dart';
import 'performance_metrics.dart';
import 'request_options.dart';
import 'swetrix_exception.dart';

/// High-level client for interacting with the Swetrix Events API.
class Swetrix {
  Swetrix({
    required this.projectId,
    SwetrixOptions options = const SwetrixOptions(),
    http.Client? httpClient,
  })  : _options = options,
        _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _baseUrl = _normaliseBase(_resolveBase(options.apiUrl));

  final String projectId;
  final http.Client _client;
  final bool _ownsClient;
  SwetrixOptions _options;
  Uri _baseUrl;
  Timer? _heartbeatTimer;
  SwetrixRequestOptions? _heartbeatRequestOptions;

  static final Uri _defaultApiUrl = Uri.parse('https://api.swetrix.com/log/');

  SwetrixOptions get options => _options;

  set options(SwetrixOptions value) {
    _options = value;
    _baseUrl = _normaliseBase(_resolveBase(value.apiUrl));
  }

  /// Sends a pageview event to Swetrix.
  Future<void> trackPageView({
    String? page,
    bool unique = false,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixPerformanceMetrics? performance,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final effectiveContext = _mergeContext(context);
    final payload = <String, Object?>{
      'pid': projectId,
      if (page != null) 'pg': page,
      if (unique) 'unique': true,
    };

    Map<String, Object?>? mergedMetadata = metadata;
    if (effectiveContext != null) {
      payload.addAll(effectiveContext.toPayload());
      mergedMetadata = _mergeMetadata(effectiveContext.toPageMetadata(), mergedMetadata);
    }

    if (mergedMetadata != null && mergedMetadata.isNotEmpty) {
      payload['meta'] = _serialiseMeta(mergedMetadata);
    }

    final perfPayload = performance?.toPayload();
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
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixRequestOptions? requestOptions,
  }) async {
    _validateEventName(eventName);

    final effectiveContext = _mergeContext(context);
    final payload = <String, Object?>{
      'pid': projectId,
      'ev': eventName,
      if (unique) 'unique': true,
      if (page != null) 'pg': page,
    };

    if (effectiveContext != null) {
      payload.addAll(effectiveContext.toPayload());
    }

    if (metadata != null && metadata.isNotEmpty) {
      payload['meta'] = _serialiseMeta(metadata);
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
  Future<void> sendHeartbeat({SwetrixRequestOptions? requestOptions}) async {
    final payload = <String, Object?>{
      'pid': projectId,
    };
    await _post('hb', payload, requestOptions: requestOptions);
  }

  /// Starts periodically sending heartbeat events.
  void startHeartbeat({
    Duration interval = const Duration(seconds: 30),
    SwetrixRequestOptions? requestOptions,
  }) {
    stopHeartbeat();
    if (_options.disabled) {
      return;
    }
    _heartbeatRequestOptions = requestOptions;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      unawaited(sendHeartbeat(requestOptions: _heartbeatRequestOptions));
    });
    unawaited(sendHeartbeat(requestOptions: requestOptions));
  }

  /// Stops automatic heartbeat requests.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatRequestOptions = null;
  }

  /// Disposes the underlying HTTP client.
  Future<void> close() async {
    stopHeartbeat();
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

    final uri = _resolve(path);
    final effectiveRequestOptions = _options.requestOptions.merge(requestOptions);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...effectiveRequestOptions.headers,
      if (effectiveRequestOptions.userAgent != null) 'User-Agent': effectiveRequestOptions.userAgent!,
      if (effectiveRequestOptions.clientIpAddress != null)
        'X-Client-IP-Address': effectiveRequestOptions.clientIpAddress!,
    };

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(_stripNulls(payload)),
    );

    if (response.statusCode >= 400) {
      throw SwetrixException(
        'Request to ${uri.path} failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  Uri _resolve(String path) {
    if (path.isEmpty) {
      return _baseUrl;
    }
    return _baseUrl.resolve(path);
  }

  static Uri _resolveBase(Uri? url) => url ?? _defaultApiUrl;

  static Uri _normaliseBase(Uri url) {
    if (url.path.endsWith('/')) {
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
        final nested = value.map((key, nestedValue) => MapEntry(key, nestedValue));
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
    final result = base == null ? <String, Object?>{} : Map<String, Object?>.from(base);
    overlay.forEach((key, value) {
      result[key] = value;
    });
    return result;
  }

  Map<String, String> _serialiseMeta(Map<String, Object?> meta) {
    if (meta.length > 100) {
      throw ArgumentError.value(meta.length, 'meta.length', 'Metadata cannot contain more than 100 keys.');
    }
    var totalLength = 0;
    final result = <String, String>{};
    meta.forEach((key, value) {
      if (value != null && value is! String && value is! num && value is! bool) {
        throw ArgumentError.value(value, 'meta[$key]', 'Metadata values must be primitive types.');
      }
      final stringValue = value == null ? 'null' : value.toString();
      totalLength += key.length + stringValue.length;
      if (totalLength > 2000) {
        throw ArgumentError('Combined metadata length cannot exceed 2000 characters.');
      }
      result[key] = stringValue;
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
