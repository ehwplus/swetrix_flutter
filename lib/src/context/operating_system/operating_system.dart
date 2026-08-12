import 'package:flutter/foundation.dart';

enum OperatingSystem {
  windows(osName: 'Windows', specifierInsideUserAgent: ''),
  linux(osName: 'Linux x86_64', specifierInsideUserAgent: 'X11'),
  macOS(osName: 'Intel Mac OS X', specifierInsideUserAgent: 'Macintosh'),
  iOS(osName: 'iPhone OS', specifierInsideUserAgent: 'iPhone'),
  iPadOS(
      osName: 'Intel Mac OS X iPad OS', specifierInsideUserAgent: 'Macintosh'),
  android(osName: 'Android', specifierInsideUserAgent: 'Linux'),
  chromeOs(osName: 'CrOS x86_64', specifierInsideUserAgent: 'X11');

  const OperatingSystem(
      {required this.osName, required this.specifierInsideUserAgent});

  /// "Mozilla/5.0 ($[specifierInsideUserAgent]; $[osName] $osVersion) ..."
  final String osName;

  /// "Mozilla/5.0 ($[specifierInsideUserAgent]; $[osName] $osVersion) ..."
  final String specifierInsideUserAgent;

  static OperatingSystem? fromUserAgent(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) {
      return null;
    }

    final ua = userAgent.toLowerCase();
    if (ua.contains('iphone')) {
      return OperatingSystem.iOS;
    }
    if (ua.contains('ipad')) {
      return OperatingSystem.iPadOS;
    }
    if (ua.contains('android')) {
      return OperatingSystem.android;
    }
    if (ua.contains('cros')) {
      return OperatingSystem.chromeOs;
    }
    if (ua.contains('windows') ||
        ua.contains('win64') ||
        ua.contains('win32')) {
      return OperatingSystem.windows;
    }
    if (ua.contains('macintosh') || ua.contains('mac os')) {
      return OperatingSystem.macOS;
    }
    if (ua.contains('linux') || ua.contains('x11')) {
      return OperatingSystem.linux;
    }
    return null;
  }

  static OperatingSystem? fromString(String? value) {
    if (value == null) {
      return null;
    }

    for (final os in OperatingSystem.values) {
      if (value.toLowerCase() == os.osName.toLowerCase()) {
        return os;
      }
      if (os.specifierInsideUserAgent.isNotEmpty &&
          value.toLowerCase() == os.specifierInsideUserAgent.toLowerCase()) {
        return os;
      }
      if (value.toLowerCase() == os.name.toLowerCase()) {
        return os;
      }
    }

    if (kDebugMode) {
      debugPrint(
          'Unknown operating system "$value". OperatingSystem.fromString returning null.');
    }
    return null;
  }
}
