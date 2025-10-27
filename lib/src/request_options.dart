import 'package:meta/meta.dart';

/// Allows customising individual requests sent to the Swetrix API.
@immutable
class SwetrixRequestOptions {
  const SwetrixRequestOptions({
    this.userAgent,
    this.clientIpAddress,
    this.headers = const <String, String>{},
  });

  /// Overrides the `User-Agent` header.
  final String? userAgent;

  /// Overrides the `X-Client-IP-Address` header.
  final String? clientIpAddress;

  /// Additional headers to append to the request.
  final Map<String, String> headers;

  SwetrixRequestOptions merge(SwetrixRequestOptions? other) {
    if (other == null) {
      return this;
    }

    final mergedHeaders = Map<String, String>.from(headers);
    mergedHeaders.addAll(other.headers);

    return SwetrixRequestOptions(
      userAgent: other.userAgent ?? userAgent,
      clientIpAddress: other.clientIpAddress ?? clientIpAddress,
      headers: mergedHeaders,
    );
  }
}
