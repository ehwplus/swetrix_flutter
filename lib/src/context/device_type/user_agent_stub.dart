import 'package:package_info_plus/package_info_plus.dart';

Future<String> resolveUserAgentForPlatform({
  required PackageInfo packageInfo,
}) async {
  final appVersion =
      packageInfo.version.isEmpty ? '0.0.0' : packageInfo.version;
  final buildNumber = packageInfo.buildNumber;
  final packageId = packageInfo.packageName.isNotEmpty
      ? packageInfo.packageName
      : 'flutter_app';

  return '$packageId/$appVersion+$buildNumber';
}
