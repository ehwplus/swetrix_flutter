import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'context/context.dart';
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
    String? userAgent,
    Future<String?> Function()? clientIpResolver,
    this.ipAddressCacheRule = IpAddressCacheRule.never,
  })  : _swetrix = Swetrix(
            projectId: projectId, options: options, httpClient: httpClient),
        _projectId = projectId,
        _sharedPreferences = sharedPreferencesFactory?.call(),
        _visitorStore = SwetrixVisitorStore(
            sharedPreferences: sharedPreferencesFactory?.call()),
        _providedUserAgent = userAgent,
        _clientIpResolver = clientIpResolver ?? _defaultClientIpResolver;

  final Swetrix _swetrix;
  final String _projectId;
  final SwetrixVisitorStore _visitorStore;
  final String? _providedUserAgent;
  final Future<String?> Function() _clientIpResolver;
  final SharedPreferences? _sharedPreferences;
  final IpAddressCacheRule ipAddressCacheRule;

  String? _userAgent;
  String? _clientIpAddress;
  Future<String?>? _clientIpFuture;

  SwetrixOptions get options => _swetrix.options;

  set options(SwetrixOptions value) {
    _swetrix.options = value;
  }

  String get projectId => _projectId;

  Future<void> reset() => _visitorStore.reset(projectId);

  Future<String> ensureVisitorId() => _visitorStore.ensureVisitorId(projectId);

  Future<void> trackPageView({
    String? page,
    bool unique = true,
    String? profileId,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixPerformanceMetrics? performanceMetrics,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final environment = await SwetrixFlutterContextBuilder.build();
    _userAgent ??= _providedUserAgent ?? environment.userAgent;

    final contextWithEnvironment = _mergeContext(environment.context, context);
    final metadataWithEnvironment =
        await _buildMetadata(environment.context, metadata);
    final metadataVisitorId = metadataWithEnvironment['visitor_id'];
    final resolvedProfileId = await _resolveProfileId(
      profileId,
      fallbackVisitorId: metadataVisitorId is String ? metadataVisitorId : null,
    );
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);

    var sendUnique = unique;
    if (unique) {
      final alreadyTracked = await _visitorStore.hasTrackedUnique(projectId);
      if (alreadyTracked) {
        sendUnique = false;
      }
    }

    await _swetrix.trackPageView(
      page: page,
      unique: sendUnique,
      profileId: resolvedProfileId,
      context: contextWithEnvironment,
      metadata: metadataWithEnvironment,
      performanceMetrics: performanceMetrics,
      requestOptions: resolvedRequestOptions,
    );

    if (unique && sendUnique) {
      await _visitorStore.markUniqueTracked(projectId);
    }
  }

  Future<void> trackEvent(
    String eventName, {
    bool unique = false,
    String? page,
    String? profileId,
    SwetrixContext? context,
    Map<String, Object?>? metadata,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final environment = await SwetrixFlutterContextBuilder.build();
    _userAgent ??= _providedUserAgent ?? environment.userAgent;

    final contextWithEnvironment = _mergeContext(environment.context, context);
    final metadataWithEnvironment =
        await _buildMetadata(environment.context, metadata);
    final metadataVisitorId = metadataWithEnvironment['visitor_id'];
    final resolvedProfileId = await _resolveProfileId(
      profileId,
      fallbackVisitorId: metadataVisitorId is String ? metadataVisitorId : null,
    );
    final resolvedRequestOptions = await _composeRequestOptions(requestOptions);

    await _swetrix.trackEvent(
      eventName,
      unique: unique,
      page: page,
      profileId: resolvedProfileId,
      context: contextWithEnvironment,
      metadata: metadataWithEnvironment,
      requestOptions: resolvedRequestOptions,
    );
  }

  Future<void> trackError(
    SwetrixErrorEvent error, {
    SwetrixContext? context,
    SwetrixRequestOptions? requestOptions,
  }) async {
    final environment = await SwetrixFlutterContextBuilder.build();
    _userAgent ??= _providedUserAgent ?? environment.userAgent;

    final contextWithEnvironment = _mergeContext(environment.context, context);
    final metadataWithEnvironment =
        await _buildMetadata(environment.context, error.metadata);
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
      metadata: metadataWithEnvironment,
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

  SwetrixContext _mergeContext(
      SwetrixContext generated, SwetrixContext? override) {
    if (override == null) {
      return generated;
    }
    return generated.merge(override);
  }

  Future<Map<String, Object?>> _buildMetadata(
    SwetrixContext generatedContext,
    Map<String, Object?>? metadata,
  ) async {
    final envMetadata = Map<String, Object?>.from(
        generatedContext.metadata ?? <String, Object?>{});
    final visitorId = await ensureVisitorId();
    envMetadata['visitor_id'] = visitorId;

    if (metadata != null) {
      envMetadata.addAll(metadata);
    }

    return envMetadata;
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

    return ensureVisitorId();
  }

  Future<SwetrixRequestOptions?> _composeRequestOptions(
      SwetrixRequestOptions? overrides) async {
    final userAgent = await _resolveUserAgent();
    final ipAddress = await _resolveClientIpAddress();

    SwetrixRequestOptions? merged = overrides;

    if ((userAgent != null && userAgent.isNotEmpty) ||
        (ipAddress != null && ipAddress.isNotEmpty)) {
      final base = SwetrixRequestOptions(
        userAgent: userAgent,
        clientIpAddress: ipAddress,
        headers: {
          if (userAgent != null && userAgent.isNotEmpty)
            'User-Agent': userAgent,
          if (ipAddress != null && ipAddress.isNotEmpty)
            'X-Client-IP-Address': ipAddress,
        },
      );

      merged = merged == null ? base : base.merge(merged);
    }

    if (merged == null) {
      return null;
    }

    final headers = <String, String>{
      ...merged.headers,
      if (merged.userAgent != null && merged.userAgent!.isNotEmpty)
        'User-Agent': merged.userAgent!,
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

    final provided = _providedUserAgent;
    if (provided != null && provided.isNotEmpty) {
      _userAgent = provided;
      return provided;
    }

    final environment = await SwetrixFlutterContextBuilder.build();
    _userAgent = environment.userAgent;
    return _userAgent;
  }

  Future<String?> _resolveClientIpAddress() async {
    if (_clientIpAddress != null && _clientIpAddress!.isNotEmpty) {
      return _clientIpAddress;
    }

    const keyClientIpAddress = 'client_ip_address';
    const keyClientIpAddressLastUpdated = 'client_ip_address_last_updated';

    if (_sharedPreferences != null &&
        ipAddressCacheRule != IpAddressCacheRule.never) {
      final cachedIpAddress = _sharedPreferences.getString(keyClientIpAddress);
      final ipAddressLastUpdated =
          _sharedPreferences.getString(keyClientIpAddressLastUpdated);
      if (cachedIpAddress != null && ipAddressLastUpdated != null) {
        final now = DateTime.now();
        final date = DateTime.tryParse(ipAddressLastUpdated);
        if (ipAddressCacheRule == IpAddressCacheRule.monthly &&
            date != null &&
            date.year == now.year &&
            date.month == now.month) {
          return cachedIpAddress;
        } else if (ipAddressCacheRule == IpAddressCacheRule.daily &&
            date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          return cachedIpAddress;
        } else {
          _sharedPreferences.remove(keyClientIpAddress);
          _sharedPreferences.remove(keyClientIpAddressLastUpdated);
        }
      }
    }

    _clientIpFuture ??= _clientIpResolver().catchError((_) => null);
    final resolved = await _clientIpFuture;

    if (resolved != null && resolved.isNotEmpty) {
      _clientIpAddress = resolved;
      if (_sharedPreferences != null) {
        _sharedPreferences.setString(keyClientIpAddress, resolved);
        _sharedPreferences.setString(
            keyClientIpAddressLastUpdated, DateTime.now().toString());
      }
      return _clientIpAddress;
    }

    _clientIpFuture = null;
    return null;
  }

  static Future<String?> _defaultClientIpResolver() async {
    try {
      final response =
          await http.get(Uri.parse('https://api.ipify.org?format=text'));
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

enum IpAddressCacheRule {
  never,
  daily,
  monthly,
}
