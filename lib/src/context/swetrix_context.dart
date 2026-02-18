import 'package:meta/meta.dart';

/// Shared contextual data that is attached to Swetrix events.
@immutable
class SwetrixContext {
  const SwetrixContext({
    this.locale,
    this.timezone,
    this.referrer,
    this.source,
    this.medium,
    this.campaign,
    this.term,
    this.content,
    this.metadata,
  });

  /// Locale of the visitor, e.g. `en-US`.
  final String? locale;

  /// Timezone of the visitor, e.g. `Europe/Berlin`.
  final String? timezone;

  /// Referrer URL.
  final String? referrer;

  /// UTM source.
  final String? source;

  /// UTM medium.
  final String? medium;

  /// UTM campaign.
  final String? campaign;

  /// UTM term.
  final String? term;

  /// UTM content.
  final String? content;

  /// Page view metadata key/value pairs.
  final Map<String, Object?>? metadata;

  /// Merges this context with [other], giving precedence to [other].
  SwetrixContext merge(SwetrixContext? other) {
    if (other == null) {
      return this;
    }

    return SwetrixContext(
      locale: other.locale ?? locale,
      timezone: other.timezone ?? timezone,
      referrer: other.referrer ?? referrer,
      source: other.source ?? source,
      medium: other.medium ?? medium,
      campaign: other.campaign ?? campaign,
      term: other.term ?? term,
      content: other.content ?? content,
      metadata: _mergeMeta(metadata, other.metadata),
    );
  }

  /// Serialises the context to a map understood by the Swetrix API.
  Map<String, Object?> toPayload() {
    return <String, Object?>{
      if (locale != null) 'lc': locale,
      if (timezone != null) 'tz': timezone,
      if (referrer != null) 'ref': referrer,
      if (source != null) 'so': source,
      if (medium != null) 'me': medium,
      if (campaign != null) 'ca': campaign,
      if (term != null) 'te': term,
      if (content != null) 'co': content,
    };
  }

  Map<String, Object?>? toPageMetadata() => metadata == null ? null : Map<String, Object?>.from(metadata!);

  Map<String, Object?>? _mergeMeta(Map<String, Object?>? base, Map<String, Object?>? override) {
    if (override == null) {
      return base;
    }
    if (base == null) {
      return Map<String, Object?>.from(override);
    }
    final merged = Map<String, Object?>.from(base);
    override.forEach((key, value) {
      if (value == null) {
        merged.remove(key);
      } else {
        merged[key] = value;
      }
    });
    return merged;
  }
}
