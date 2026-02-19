import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import 'device_info_model.dart';

Future<SwetrixDeviceInfo> resolveDeviceInfoForPlatform() async {
  final deviceInfoPlugin = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return SwetrixDeviceInfo(
        deviceModel: androidInfo.model, // e.g. Pixel 10
        manufacturer: androidInfo.manufacturer, // e.g. Google
        os: 'android',
        osVersion: androidInfo.version.release, // e.g. 16
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return SwetrixDeviceInfo(
        deviceModel: iosInfo.utsname.machine, // e.g. iPod7.1
        manufacturer: 'Apple',
        os: 'iOS',
        osVersion: iosInfo.systemVersion,
      );
    } else if (Platform.isMacOS) {
      final macOsDeviceInfo = await deviceInfoPlugin.macOsInfo;
      return SwetrixDeviceInfo(
        deviceModel: macOsDeviceInfo.model, // e.g. MacBook Pro (16-inch, 2021)
        manufacturer: 'Apple',
        os: 'macOS',
        osVersion:
            '${macOsDeviceInfo.majorVersion}.${macOsDeviceInfo.minorVersion}.${macOsDeviceInfo.patchVersion}',
      );
    } else if (Platform.isWindows) {
      final windowsDeviceInfo = await deviceInfoPlugin.windowsInfo;
      return SwetrixDeviceInfo(
        deviceModel: windowsDeviceInfo.deviceId,
        os: 'windows',
        osVersion: windowsDeviceInfo.productName,
      );
    } else if (Platform.isLinux) {
      final linuxDeviceInfo = await deviceInfoPlugin.linuxInfo;
      return SwetrixDeviceInfo(
        deviceModel: linuxDeviceInfo.machineId,
        os: linuxDeviceInfo.name,
        osVersion: linuxDeviceInfo.version,
      );
    }
  } on MissingPluginException {
    return SwetrixDeviceInfo(
      os: Platform.operatingSystem,
    );
  } catch (_) {
    return SwetrixDeviceInfo(
      os: Platform.operatingSystem,
    );
  }

  return SwetrixDeviceInfo(
    os: Platform.operatingSystem,
    osVersion: Platform.operatingSystemVersion
        .split(' (Build ')[0]
        .replaceAll('Version ', ''),
  );
}
