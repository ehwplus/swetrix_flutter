/// Thrown when the Swetrix API returns an unexpected response.
class SwetrixException implements Exception {
  SwetrixException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() {
    final buffer = StringBuffer('SwetrixException: $message');
    if (statusCode != null) {
      buffer.write(' (statusCode: $statusCode');
      if (body != null && body!.isNotEmpty) {
        buffer.write(', body: $body');
      }
      buffer.write(')');
    }
    return buffer.toString();
  }
}
