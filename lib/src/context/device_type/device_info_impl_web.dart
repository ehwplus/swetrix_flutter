import 'package:device_info_plus/device_info_plus.dart';
import 'package:swetrix_flutter/src/context/operating_system/operating_system.dart';

import 'device_info_model.dart';

Future<SwetrixDeviceInfo> resolveDeviceInfoForPlatform() async {
  final deviceInfoPlugin = DeviceInfoPlugin();
  final webBrowserInfo = await deviceInfoPlugin.webBrowserInfo;
  final userAgent = webBrowserInfo.userAgent;
  final os = OperatingSystem.fromUserAgent(userAgent);

  return SwetrixDeviceInfo(
    os: os?.name,
    browserName: webBrowserInfo.browserName.name,
  );
}
