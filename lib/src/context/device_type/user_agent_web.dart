// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:package_info_plus/package_info_plus.dart';

import 'dart:html' as html;

Future<String> resolveUserAgentForPlatform({
  required PackageInfo packageInfo,
}) async {
  final browserUserAgent = html.window.navigator.userAgent;

  if (browserUserAgent.isNotEmpty) {
    return browserUserAgent;
  }

  final appVersion = packageInfo.version.isEmpty ? '0.0.0' : packageInfo.version;
  final buildNumber = packageInfo.buildNumber;
  final packageId = packageInfo.packageName.isNotEmpty ? packageInfo.packageName : 'flutter_app';
  return '$packageId/$appVersion+$buildNumber';
}
