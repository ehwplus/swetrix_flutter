import 'package:flutter_test/flutter_test.dart';
import 'package:swetrix_flutter/src/context/operating_system/operating_system.dart';

void main() {
  group('OperatingSystem.fromUserAgent', () {
    test('does not classify every UA as Windows', () {
      expect(
        OperatingSystem.fromUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
        ),
        OperatingSystem.macOS,
      );
      expect(
        OperatingSystem.fromUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36',
        ),
        OperatingSystem.android,
      );
    });

    test('matches windows, ios, ipad and chrome os', () {
      expect(
        OperatingSystem.fromUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ),
        OperatingSystem.windows,
      );
      expect(
        OperatingSystem.fromUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X)',
        ),
        OperatingSystem.iOS,
      );
      expect(
        OperatingSystem.fromUserAgent(
          'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)',
        ),
        OperatingSystem.iPadOS,
      );
      expect(
        OperatingSystem.fromUserAgent(
          'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36',
        ),
        OperatingSystem.chromeOs,
      );
    });
  });
}
