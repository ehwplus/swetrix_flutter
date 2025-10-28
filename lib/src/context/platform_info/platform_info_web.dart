// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'platform_info.dart';

PlatformInfo loadPlatformInfo() {
  final userAgent = html.window.navigator.userAgent;
  final operatingSystem = _extractOperatingSystem(userAgent);
  final osVersion = _extractOperatingSystemVersion(userAgent);
  final browser = _extractBrowser(userAgent);

  return PlatformInfo(
    operatingSystem: operatingSystem,
    operatingSystemVersion: osVersion,
    browserName: browser,
    userAgent: userAgent,
  );
}

String _extractOperatingSystem(String userAgent) {
  final ua = userAgent.toLowerCase();
  if (ua.contains('windows nt')) {
    return 'Windows';
  }
  if (ua.contains('mac os x')) {
    return 'macOS';
  }
  if (ua.contains('iphone')) {
    return 'iOS';
  }
  if (ua.contains('ipad')) {
    return 'iPadOS';
  }
  if (ua.contains('android')) {
    return 'Android';
  }
  if (ua.contains('linux')) {
    return 'Linux';
  }
  if (ua.contains('cros')) {
    return 'ChromeOS';
  }
  return 'Web';
}

String? _extractOperatingSystemVersion(String userAgent) {
  String? match(String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    final match = regex.firstMatch(userAgent);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.replaceAll('_', '.');
    }
    return null;
  }

  return match(r'Windows NT ([0-9._]+)') ??
      match(r'Mac OS X ([0-9_]+)') ??
      match(r'iPhone OS ([0-9_]+)') ??
      match(r'iPad OS ([0-9_]+)') ??
      match(r'Android ([0-9.]+)') ??
      match(r'CrOS [^ ]+ ([0-9.]+)');
}

String? _extractBrowser(String userAgent) {
  if (userAgent.contains('Edg/')) {
    return 'Edge';
  }
  if (userAgent.contains('OPR/') || userAgent.contains('Opera')) {
    return 'Opera';
  }
  if (userAgent.contains('Firefox/')) {
    return 'Firefox';
  }
  if (userAgent.contains('Chrome/')) {
    return userAgent.contains('Chromium') ? 'Chromium' : 'Chrome';
  }
  if (userAgent.contains('Safari/')) {
    return 'Safari';
  }
  return null;
}
