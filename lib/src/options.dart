import 'package:meta/meta.dart';

import 'context.dart';
import 'request_options.dart';

/// Global configuration for the Swetrix client.
@immutable
class SwetrixOptions {
  const SwetrixOptions({
    this.apiUrl,
    this.disabled = false,
    this.defaultContext,
    this.requestOptions = const SwetrixRequestOptions(),
  });

  /// Base URL of the Swetrix Events API. When null, the production API is used.
  final Uri? apiUrl;

  /// When set to `true`, no requests will be sent.
  final bool disabled;

  /// Context automatically attached to every outgoing event.
  final SwetrixContext? defaultContext;

  /// Default request options (headers, user agent, etc.).
  final SwetrixRequestOptions requestOptions;

  SwetrixOptions copyWith({
    Uri? apiUrl,
    bool? disabled,
    SwetrixContext? defaultContext,
    SwetrixRequestOptions? requestOptions,
  }) {
    return SwetrixOptions(
      apiUrl: apiUrl ?? this.apiUrl,
      disabled: disabled ?? this.disabled,
      defaultContext: defaultContext ?? this.defaultContext,
      requestOptions: requestOptions ?? this.requestOptions,
    );
  }
}
