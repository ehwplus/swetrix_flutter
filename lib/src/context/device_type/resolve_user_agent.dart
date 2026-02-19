import 'package:package_info_plus/package_info_plus.dart';

import 'user_agent_stub.dart'
    if (dart.library.io) 'user_agent_io.dart'
    if (dart.library.html) 'user_agent_web.dart';

/// example value for Android (emulator):
/// "Mozilla/5.0 (Linux; Android 16) AppleWebKit/605.1.15 (KHTML, like Gecko) com.example.swetrix_example/0.1.0+1; Google; sdk_gphone64_arm64; tablet"
///
/// example value for web app:
/// "Mozilla/5.0 (Macintosh; Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"
///
/// example value for macOS app:
/// "Mozilla/5.0 (Macintosh; Mac OS X 15_7_1) AppleWebKit/605.1.15 (KHTML, like Gecko) com.example.swetrixExample/0.1.0+1; Apple; MacBookPro18,3; desktop Safari/605.1.15"
Future<String> resolveUserAgent({
  required PackageInfo packageInfo,
}) =>
    resolveUserAgentForPlatform(packageInfo: packageInfo);
