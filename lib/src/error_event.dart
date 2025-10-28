import 'package:meta/meta.dart';

/// Payload for Swetrix error tracking.
@immutable
class SwetrixErrorEvent {
  const SwetrixErrorEvent({
    required this.name,
    this.message,
    this.lineNumber,
    this.columnNumber,
    this.fileName,
    this.stackTrace,
    this.page,
    this.timezone,
    this.locale,
    this.metadata,
  });

  final String name;
  final String? message;
  final int? lineNumber;
  final int? columnNumber;
  final String? fileName;
  final String? stackTrace;
  final String? page;
  final String? timezone;
  final String? locale;
  final Map<String, Object?>? metadata;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'name': name,
      if (message != null) 'message': message,
      if (lineNumber != null) 'lineno': lineNumber,
      if (columnNumber != null) 'colno': columnNumber,
      if (fileName != null) 'filename': fileName,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (page != null) 'pg': page,
      if (timezone != null) 'tz': timezone,
      if (locale != null) 'lc': locale,
      if (metadata != null && metadata!.isNotEmpty)
        'meta': Map<String, Object?>.from(metadata!),
    };
  }
}
