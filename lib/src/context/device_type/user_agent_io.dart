import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:swetrix_flutter/src/context/operating_system/operating_system.dart';

import 'resolve_device_info.dart';
import 'resolve_device_type.dart';

Future<String> resolveUserAgentForPlatform({
  required PackageInfo packageInfo,
}) async {
  final appVersion =
      packageInfo.version.isEmpty ? '0.0.0' : packageInfo.version;
  final buildNumber = packageInfo.buildNumber;
  final packageId = packageInfo.packageName.isNotEmpty
      ? packageInfo.packageName
      : 'flutter_app';

  final productVersion = '$appVersion+$buildNumber';
  final deviceInfo = await resolveDeviceInfo();
  final OperatingSystem? os =
      OperatingSystem.fromString(deviceInfo.os ?? Platform.operatingSystem);
  final osVersion = deviceInfo.osVersion;
  final manufacturer = deviceInfo.manufacturer;
  final deviceModel = deviceInfo.deviceModel;
  final deviceType = resolveDeviceType();

  if (os != null) {
    return _buildUserAgent(
      packageId: packageId,
      productVersion: productVersion,
      os: os,
      osVersion: osVersion,
      manufacturer: manufacturer,
      deviceModel: deviceModel,
      deviceType: deviceType,
    );
  }

  final systemInformation = [
    os,
    osVersion,
    manufacturer,
    deviceModel,
    deviceType
  ].nonNulls.toList().toString().replaceAll('[', '').replaceAll(']', '');
  final platform = ' Dart ${Platform.version.split(' (stable) ')[0]}';
  final appSection = ' $packageId/$productVersion';

  return 'Mozilla/5.0 ($systemInformation)$appSection$platform';
}

String _buildUserAgent({
  required String packageId,
  required String productVersion,
  required OperatingSystem os,
  String? osVersion,
  String? manufacturer,
  String? deviceModel,
  String? deviceType,
}) {
  final normalisedVersion = osVersion?.replaceAll('.', '_');
  final osToken = (normalisedVersion == null || normalisedVersion.isEmpty)
      ? os.osName
      : '${os.osName} $normalisedVersion';
  final appSection = '$packageId/$productVersion';
  final details = [
    os.specifierInsideUserAgent,
    osToken,
    manufacturer,
    deviceModel,
    deviceType
  ].whereType<String>().where((value) => value.isNotEmpty).join('; ');

  String resolveBrowserSection() {
    switch (os) {
      case OperatingSystem.windows:
        return 'Chrome/121.0.0.0 Safari/537.36';
      case OperatingSystem.linux:
        return 'Gecko/20100101 Firefox/122.0';
      case OperatingSystem.macOS:
        return 'Version/17.2 Safari/605.1.15';
      case OperatingSystem.iOS:
        return 'Version/17.2 Mobile/15E148 Safari/604.1';
      case OperatingSystem.iPadOS:
        return 'Version/17.0 Safari/605.1.15';
      case OperatingSystem.android:
        return 'Chrome/121.0.0.0 Mobile Safari/537.36';
      case OperatingSystem.chromeOs:
        return 'Chrome/121.0.0.0 Safari/537.36';
    }
  }

  final browserSection = resolveBrowserSection();

  return 'Mozilla/5.0 ${details.isNotEmpty ? '($details)' : ''}'
      'AppleWebKit/605.1.15 (KHTML, like Gecko)'
      ' $appSection'
      '${browserSection.isNotEmpty ? ' $browserSection' : ''}';
}
