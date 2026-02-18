import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swetrix_flutter/src/exceptions/forbidden_403_not_unique.dart';

import 'context/swetrix_context.dart';
import 'error_event.dart';
import 'options.dart';
import 'performance_metrics.dart';
import 'request_options.dart';
import 'swetrix.dart';
import 'context/flutter_context_builder.dart';
import 'context/visitor/visitor_store.dart';

/// Flutter-friendly wrapper around [Swetrix] that enriches events with device metadata.
class SwetrixFlutterClient {
  SwetrixFlutterClient({
    required String projectId,
    SwetrixOptions options = const SwetrixOptions(),
    http.Client? httpClient,
    SharedPreferencesFactory? sharedPreferencesFactory,
    Future<String?> Function()? clientIpResolver,
  })  : _swetrix = Swetrix(projectId: projectId, options: options, httpClient: httpClient),
        _projectId = projectId,
        _visitorStore = SwetrixVisitorStore(sharedPreferences: sharedPreferencesFactory?.call()),
        _clientIpResolver = clientIpResolver ?? _defaultClientIpResolver;

  final Swetrix _swetrix;
  final String _projectId;
  final SwetrixVisitorStore _visitorStore;
  final Future<String?> Function() _clientIpResolver;

  String? _userAgent;
  String? _clientIpAddress;
  Future<String?>? _clientIpFuture;

  SwetrixOptions get options => _swetrix.options;

  set options(SwetrixOptions value) {
    _swetrix.options = value;
  }

  String get projectId => _projectId;

  Future<void> reset() => _visitorStore.reset(projectId);

  Future<String> _resolveVisitorId() => _visitorStore.ensureVisitorId(projectId);

  Future<void> trackPageView({
    String? page,
    String? profileId,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixPerformanceMetrics? performanceMetrics,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final environment = await SwetrixContextBuilder.build();
    _userAgent ??= environment.userAgent;

    final contextWithEnvironment = _mergeContext(environment.context, context);
    final profileId = await _resolveVisitorId();
    final metaData = environment.context.metadata;
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);

    await _swetrix.trackPageView(
      page: page,
      profileId: profileId,
      context: contextWithEnvironment,
      metadata: metaData,
      performanceMetrics: performanceMetrics,
      requestOptions: resolvedRequestOptions,
    );
  }

  /// If [unique] is true, make sure the event is just sent once.
  /// Otherwise a [Forbidden403NotUnique] exception is thrown.
  Future<void> trackEvent(
    String eventName, {
    bool unique = false,
    String? page,
    String? profileId,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final environment = await SwetrixContextBuilder.build();
    _userAgent ??= environment.userAgent;

    final contextWithEnvironment = _mergeContext(environment.context, context);
    final profileId = await _resolveVisitorId();
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);

    await _swetrix.trackEvent(
      eventName,
      unique: unique,
      page: page,
      profileId: profileId,
      context: contextWithEnvironment,
      metadata: metadata,
      requestOptions: resolvedRequestOptions,
    );
  }

  Future<void> trackError(
    SwetrixErrorEvent error, {
    SwetrixContext? context,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final environment = await SwetrixContextBuilder.build();
    _userAgent ??= environment.userAgent;

    final contextWithEnvironment = _mergeContext(environment.context, context);
    final metadata = environment.context.metadata;
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);

    final decoratedError = SwetrixErrorEvent(
      name: error.name,
      message: error.message,
      lineNumber: error.lineNumber,
      columnNumber: error.columnNumber,
      fileName: error.fileName,
      stackTrace: error.stackTrace,
      page: error.page,
      timezone: error.timezone ?? contextWithEnvironment.timezone,
      locale: error.locale ?? contextWithEnvironment.locale,
      metadata: metadata,
    );

    await _swetrix.trackError(
      decoratedError,
      context: contextWithEnvironment,
      requestOptions: resolvedRequestOptions,
    );
  }

  Future<void> sendHeartbeat({
    String? profileId,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final resolvedProfileId = await _resolveProfileId(profileId);
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);
    return _swetrix.sendHeartbeat(
      profileId: resolvedProfileId,
      requestOptions: resolvedRequestOptions,
    );
  }

  void startHeartbeat({
    Duration interval = const Duration(seconds: 30),
    String? profileId,
    SwetrixRequestOptions? requestOptions,
  }) =>
      _swetrix.startHeartbeat(
        interval: interval,
        profileId: profileId ?? options.profileId,
        requestOptions: requestOptions,
      );

  void stopHeartbeat() => _swetrix.stopHeartbeat();

  Future<void> close() => _swetrix.close();

  Future<Map<String, bool>> getFeatureFlags({
    String? profileId,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final resolvedProfileId = await _resolveProfileId(profileId);
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);
    return _swetrix.getFeatureFlags(
      profileId: resolvedProfileId,
      forceRefresh: forceRefresh,
      requestOptions: resolvedRequestOptions,
    );
  }

  Future<bool> getFeatureFlag(
    String key, {
    String? profileId,
    bool defaultValue = false,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final resolvedProfileId = await _resolveProfileId(profileId);
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);
    return _swetrix.getFeatureFlag(
      key,
      profileId: resolvedProfileId,
      defaultValue: defaultValue,
      forceRefresh: forceRefresh,
      requestOptions: resolvedRequestOptions,
    );
  }

  Future<Map<String, String>> getExperiments({
    String? profileId,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final resolvedProfileId = await _resolveProfileId(profileId);
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);
    return _swetrix.getExperiments(
      profileId: resolvedProfileId,
      forceRefresh: forceRefresh,
      requestOptions: resolvedRequestOptions,
    );
  }

  Future<String?> getExperiment(
    String experimentId, {
    String? profileId,
    String? defaultVariant,
    bool forceRefresh = false,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final resolvedProfileId = await _resolveProfileId(profileId);
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);
    return _swetrix.getExperiment(
      experimentId,
      profileId: resolvedProfileId,
      defaultVariant: defaultVariant,
      forceRefresh: forceRefresh,
      requestOptions: resolvedRequestOptions,
    );
  }

  void clearFeatureFlagsCache() => _swetrix.clearFeatureFlagsCache();

  void clearExperimentsCache() => _swetrix.clearExperimentsCache();

  int get pendingQueueLength => _swetrix.pendingQueueLength;

  Future<void> flushQueue() => _swetrix.flushQueue();

  SwetrixContext _mergeContext(SwetrixContext generated, SwetrixContext? override) {
    if (override == null) {
      return generated;
    }
    return generated.merge(override);
  }

  Future<String> _resolveProfileId(
    String? overrideProfileId, {
    String? fallbackVisitorId,
  }) async {
    if (overrideProfileId != null && overrideProfileId.isNotEmpty) {
      return overrideProfileId;
    }

    final configuredProfileId = options.profileId;
    if (configuredProfileId != null && configuredProfileId.isNotEmpty) {
      return configuredProfileId;
    }

    if (fallbackVisitorId != null && fallbackVisitorId.isNotEmpty) {
      return fallbackVisitorId;
    }

    return _resolveVisitorId();
  }

  Future<SwetrixRequestOptions?> _composeRequestOptions(SwetrixRequestOptions? overrides) async {
    final userAgent = await _resolveUserAgent();
    final ipAddress = await _resolveClientIpAddress();

    SwetrixRequestOptions? merged = overrides;

    if ((userAgent != null && userAgent.isNotEmpty) || (ipAddress != null && ipAddress.isNotEmpty)) {
      final base = SwetrixRequestOptions(
        userAgent: userAgent,
        clientIpAddress: ipAddress,
        headers: {
          if (userAgent != null && userAgent.isNotEmpty) 'User-Agent': userAgent,
          if (ipAddress != null && ipAddress.isNotEmpty) 'X-Client-IP-Address': ipAddress,
        },
      );

      merged = merged == null ? base : base.merge(merged);
    }

    if (merged == null) {
      return null;
    }

    final headers = <String, String>{
      ...merged.headers,
      if (merged.userAgent != null && merged.userAgent!.isNotEmpty) 'User-Agent': merged.userAgent!,
      if (merged.clientIpAddress != null && merged.clientIpAddress!.isNotEmpty)
        'X-Client-IP-Address': merged.clientIpAddress!,
    };

    return SwetrixRequestOptions(
      userAgent: merged.userAgent,
      clientIpAddress: merged.clientIpAddress,
      headers: headers,
    );
  }

  Future<String?> _resolveUserAgent() async {
    final existing = _userAgent;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final environment = await SwetrixContextBuilder.build();
    _userAgent = environment.userAgent;
    return _userAgent;
  }

  Future<String?> _resolveClientIpAddress() async {
    if (_clientIpAddress != null && _clientIpAddress!.isNotEmpty) {
      return _clientIpAddress;
    }

    _clientIpFuture ??= _clientIpResolver().catchError((_) => null);
    final resolved = await _clientIpFuture;

    if (resolved != null && resolved.isNotEmpty) {
      _clientIpAddress = resolved;
      return _clientIpAddress;
    }

    _clientIpFuture = null;
    return null;
  }

  static Future<String?> _defaultClientIpResolver() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=text'));
      if (response.statusCode == 200) {
        final ip = response.body.trim();
        if (ip.isNotEmpty) {
          return ip;
        }
      }
    } catch (_) {
      // Ignored: we can proceed without an IP header if resolution fails.
    }
    return null;
  }
}

typedef SharedPreferencesFactory = SharedPreferences? Function();
