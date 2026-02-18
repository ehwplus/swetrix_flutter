import 'package:meta/meta.dart';

import 'context/swetrix_context.dart';
import 'request_options.dart';

/// Global configuration for the Swetrix client.
@immutable
class SwetrixOptions {
  const SwetrixOptions({
    this.apiUrl,
    this.disabled = false,
    this.profileId,
    this.queueFailedRequests = true,
    this.maxQueueSize = 500,
    this.queueRetryInterval = const Duration(seconds: 15),
    this.defaultContext,
    this.requestOptions = const SwetrixRequestOptions(),
  });

  /// Base URL of the Swetrix Events API. When null, the production API is used.
  final Uri? apiUrl;

  /// When set to `true`, no requests will be sent.
  final bool disabled;

  /// Optional long-term profile identifier used for MAU and feature flag evaluation.
  final String? profileId;

  /// Queues tracking requests when delivery fails (for example offline/network errors).
  final bool queueFailedRequests;

  /// Maximum number of queued requests kept in memory.
  final int maxQueueSize;

  /// Delay before retrying queued requests.
  final Duration queueRetryInterval;

  /// Context automatically attached to every outgoing event.
  final SwetrixContext? defaultContext;

  /// Default request options (headers, user agent, etc.).
  final SwetrixRequestOptions requestOptions;

  SwetrixOptions copyWith({
    Uri? apiUrl,
    bool? disabled,
    String? profileId,
    bool? queueFailedRequests,
    int? maxQueueSize,
    Duration? queueRetryInterval,
    SwetrixContext? defaultContext,
    SwetrixRequestOptions? requestOptions,
  }) {
    return SwetrixOptions(
      apiUrl: apiUrl ?? this.apiUrl,
      disabled: disabled ?? this.disabled,
      profileId: profileId ?? this.profileId,
      queueFailedRequests: queueFailedRequests ?? this.queueFailedRequests,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      queueRetryInterval: queueRetryInterval ?? this.queueRetryInterval,
      defaultContext: defaultContext ?? this.defaultContext,
      requestOptions: requestOptions ?? this.requestOptions,
    );
  }
}
