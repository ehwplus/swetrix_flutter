import 'dart:io' as io;

import 'platform_info.dart';

PlatformInfo loadPlatformInfo() {
  return PlatformInfo(
    operatingSystem: io.Platform.operatingSystem,
    operatingSystemVersion: io.Platform.operatingSystemVersion,
    userAgent: null,
    browserName: null,
  );
}
