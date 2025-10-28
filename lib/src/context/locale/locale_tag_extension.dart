import 'package:flutter/widgets.dart';

/// Return locale tag '$language-$country', eg. 'de-DE
extension LocaleTag on Locale {
  toLocaleTag() {
    try {
      return toLanguageTag();
    } catch (_) {
      final language = languageCode;
      final country = countryCode;
      if (country == null || country.isEmpty) {
        return language;
      }
      return '$language-$country';
    }
  }
}
