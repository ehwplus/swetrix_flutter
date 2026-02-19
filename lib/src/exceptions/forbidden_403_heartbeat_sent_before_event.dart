/// Thrown when the Swetrix API returns an unexpected response.
class Forbidden403HeartbeatSentBeforeEvent implements Exception {
  Forbidden403HeartbeatSentBeforeEvent(this.message, {this.body});

  final String message;
  final String? body;

  @override
  String toString() {
    final buffer =
        StringBuffer('Forbidden403HeartbeatSentBeforeEvent: $message');
    buffer.write(' (statusCode: 403');
    if (body != null && body!.isNotEmpty) {
      buffer.write(', body: $body');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
