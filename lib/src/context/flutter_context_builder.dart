import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'swetrix_context.dart';
import 'device_type/resolve_device_info.dart';
import 'device_type/resolve_user_agent.dart';
import 'locale/locale_tag_extension.dart';
import 'timezone/resolve_timezone.dart';

class SwetrixFlutterEnvironment {
  const SwetrixFlutterEnvironment({
    required this.context,
    required this.userAgent,
  });

  final SwetrixContext context;
  final String userAgent;
}

/// Builds a [SwetrixFlutterEnvironment] enriched with device, locale and app metadata.
class SwetrixContextBuilder {
  const SwetrixContextBuilder._();

  static Future<SwetrixFlutterEnvironment> build() async {
    WidgetsFlutterBinding.ensureInitialized();
    final dispatcher = WidgetsBinding.instance.platformDispatcher;

    final locale = dispatcher.locale;

    final deviceInfo = await resolveDeviceInfo();
    final os = deviceInfo.os;
    final osVersion = deviceInfo.osVersion;

    final packageInfo = await PackageInfo.fromPlatform();
    final metadata = <String, Object?>{
      'os': os,
      if (osVersion != null) 'os_version': osVersion,
      if (deviceInfo.manufacturer != null)
        'manufacturer': deviceInfo.manufacturer,
      if (deviceInfo.deviceModel != null) 'deviceModel': deviceInfo.deviceModel,
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      'language': locale.languageCode,
      if (locale.countryCode != null) 'country': locale.countryCode,
      if (deviceInfo.browserName != null) 'browser': deviceInfo.browserName,
    };

    final timezone = resolveTimezone();

    final swetrixContext = SwetrixContext(
      locale: locale.toLocaleTag(),
      timezone: timezone,
      metadata: metadata,
    );

    final userAgent = await resolveUserAgent(
      packageInfo: packageInfo,
    );
    if (kDebugMode) {
      debugPrint('userAgent: $userAgent');
    }

    return SwetrixFlutterEnvironment(
      context: swetrixContext,
      userAgent: userAgent,
    );
  }
}
