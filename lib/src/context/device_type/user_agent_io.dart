import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:swetrix_flutter/src/context/operating_system/operating_system.dart';

import 'resolve_device_info.dart';
import 'resolve_device_type.dart';

Future<String> resolveUserAgentForPlatform({
  required PackageInfo packageInfo,
}) async {
  final appVersion = packageInfo.version.isEmpty ? '0.0.0' : packageInfo.version;
  final buildNumber = packageInfo.buildNumber;
  final packageId = packageInfo.packageName.isNotEmpty ? packageInfo.packageName : 'flutter_app';

  final productVersion = '$appVersion+$buildNumber';
  final deviceInfo = await resolveDeviceInfo();
  final OperatingSystem? os = OperatingSystem.fromString(deviceInfo.os ?? Platform.operatingSystem);
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

  final systemInformation = [os, osVersion, manufacturer, deviceModel, deviceType]
      .nonNulls
      .toList()
      .toString()
      .replaceAll('[', '')
      .replaceAll(']', '');
  final platform = ' Dart ${Platform.version.split(' (stable) ')[0]}';

  return '$packageId/$productVersion ($systemInformation)$platform';
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
  final osName = os.nameFormatted;
  final osToken = (normalisedVersion == null || normalisedVersion.isEmpty) ? osName : '$osName $normalisedVersion';
  final appToken = '$packageId/$productVersion';
  final details =
      [manufacturer, deviceModel, deviceType].whereType<String>().where((value) => value.isNotEmpty).join('; ');
  final appSection = details.isEmpty ? appToken : '$appToken; $details';
  final browserSection = '';

  return 'Mozilla/5.0 (${os.specifierInsideUserAgent}; $osToken) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko)'
      ' $appSection'
      '${browserSection.isNotEmpty ? ' $browserSection' : ''}';
}
