import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'context.dart';
import 'device_type/resolve_device_type.dart';
import 'locale/locale_tag_extension.dart';
import 'platform_info/platform_info.dart';
import 'timezone/resolve_timezone.dart';

class SwetrixFlutterEnvironment {
  const SwetrixFlutterEnvironment(
      {required this.context, required this.userAgent});

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

    Future<({String? deviceModel, String? manufacturer, String? osVersion})>
        getDeviceInfo() async {
      DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      if (kIsWeb) {
        return (deviceModel: null, manufacturer: null, osVersion: null);
      } else if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        return (
          deviceModel: androidInfo.model, // e.g. Pixel 10
          manufacturer: androidInfo.manufacturer, // e.g. Google
          osVersion: androidInfo.version.release, // e.g. 16
        );
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        return (
          deviceModel: iosInfo.utsname.machine, // e.g. iPod7.1
          manufacturer: 'Apple',
          osVersion: iosInfo.systemVersion
        );
      } else if (Platform.isIOS) {
        MacOsDeviceInfo macOsDeviceInfo = await deviceInfoPlugin.macOsInfo;
        return (
          deviceModel:
              macOsDeviceInfo.model, // e.g. MacBook Pro (16-inch, 2021)
          manufacturer: 'Apple',
          osVersion:
              '${macOsDeviceInfo.majorVersion}.${macOsDeviceInfo.minorVersion}.${macOsDeviceInfo.patchVersion}',
        );
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsDeviceInfo =
            await deviceInfoPlugin.windowsInfo;
        return (
          deviceModel: windowsDeviceInfo.deviceId,
          manufacturer: null,
          osVersion: windowsDeviceInfo.productName,
        );
      } else {
        return (deviceModel: null, manufacturer: null, osVersion: null);
      }
    }

    final deviceInfo = await getDeviceInfo();

    final metadata = <String, Object?>{
      'os': platformInfo.operatingSystem,
      if (deviceInfo.osVersion != null) 'os_version': deviceInfo.osVersion,
      if (deviceInfo.manufacturer != null)
        'manufacturer': deviceInfo.manufacturer,
      if (deviceInfo.deviceModel != null) 'deviceModel': deviceInfo.deviceModel,
      'device_type': resolveDeviceType(dispatcher: dispatcher),
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      if (locale.languageCode.isNotEmpty) 'language': locale.languageCode,
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        'country': locale.countryCode,
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

  static String _buildUserAgent(
      {required PlatformInfo platformInfo, required PackageInfo packageInfo}) {
    final existing = platformInfo.userAgent;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final buffer = StringBuffer()
      ..write(packageInfo.packageName.isEmpty
          ? 'flutter_app'
          : packageInfo.packageName)
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

    if (platformInfo.operatingSystemVersion != null &&
        platformInfo.operatingSystemVersion!.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(platformInfo.operatingSystemVersion);
    }

    buffer.write(')');
    return buffer.toString();
  }
}
