import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    if (dart.library.html) 'platform_info_web.dart';

class PlatformInfo {
  const PlatformInfo({
    required this.operatingSystem,
    this.operatingSystemVersion,
    this.browserName,
    this.userAgent,
  });

  final String operatingSystem;
  final String? operatingSystemVersion;
  final String? browserName;
  final String? userAgent;
}

PlatformInfo resolvePlatformInfo() => loadPlatformInfo();
