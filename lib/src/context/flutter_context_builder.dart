import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'context.dart';
import 'device_type/resolve_device_type.dart';
import 'locale/locale_tag_extension.dart';
import 'platform_info/platform_info.dart';
import 'timezone/resolve_timezone.dart';

class SwetrixFlutterEnvironment {
  const SwetrixFlutterEnvironment({required this.context, required this.userAgent});

  final SwetrixContext context;
  final String userAgent;
}

/// Builds a [SwetrixFlutterEnvironment] enriched with device, locale and app metadata.
class SwetrixFlutterContextBuilder {
  const SwetrixFlutterContextBuilder._();

  static Future<SwetrixFlutterEnvironment> build() async {
    WidgetsFlutterBinding.ensureInitialized();
    final dispatcher = WidgetsBinding.instance.platformDispatcher;

    final locale = dispatcher.locale;
    final platformInfo = resolvePlatformInfo();
    final packageInfo = await PackageInfo.fromPlatform();

    final metadata = <String, Object?>{
      'os': platformInfo.operatingSystem,
      if (platformInfo.operatingSystemVersion != null) 'os_version': platformInfo.operatingSystemVersion,
      'device_type': resolveDeviceType(dispatcher: dispatcher),
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      if (locale.languageCode.isNotEmpty) 'language': locale.languageCode,
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty) 'country': locale.countryCode,
      if (platformInfo.browserName != null) 'browser': platformInfo.browserName,
    };

    final timezone = resolveTimezone();
    final languageTag = locale.toLocaleTag();

    final context = SwetrixContext(
      locale: languageTag,
      timezone: timezone,
      metadata: metadata,
    );

    final userAgent = _buildUserAgent(
      platformInfo: platformInfo,
      packageInfo: packageInfo,
    );

    return SwetrixFlutterEnvironment(
      context: context,
      userAgent: userAgent,
    );
  }

  static String _buildUserAgent({required PlatformInfo platformInfo, required PackageInfo packageInfo}) {
    final existing = platformInfo.userAgent;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final buffer = StringBuffer()
      ..write(packageInfo.packageName.isEmpty ? 'flutter_app' : packageInfo.packageName)
      ..write('/')
      ..write(packageInfo.version.isEmpty ? '0.0.0' : packageInfo.version);

    if (packageInfo.buildNumber.isNotEmpty) {
      buffer
        ..write('+')
        ..write(packageInfo.buildNumber);
    }

    buffer
      ..write(' (')
      ..write(platformInfo.operatingSystem);

    if (platformInfo.operatingSystemVersion != null && platformInfo.operatingSystemVersion!.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(platformInfo.operatingSystemVersion);
    }

    buffer.write(')');
    return buffer.toString();
  }
}
