enum OperatingSystem {
  windows(nameFormatted: 'Windows', specifierInsideUserAgent: 'Windows nt'),
  linux(nameFormatted: 'Linux', specifierInsideUserAgent: 'Linux'),
  maxOS(nameFormatted: 'Mac OS X', specifierInsideUserAgent: 'Macintosh'),
  iOS(nameFormatted: 'iOS', specifierInsideUserAgent: 'iPhone'),
  iPadOS(nameFormatted: 'iPadOS', specifierInsideUserAgent: 'iPad'),
  android(nameFormatted: 'Android', specifierInsideUserAgent: 'Android'),
  chromeOs(nameFormatted: 'ChromeOS', specifierInsideUserAgent: 'cros');

  const OperatingSystem({required this.nameFormatted, required this.specifierInsideUserAgent});

  final String nameFormatted;

  final String specifierInsideUserAgent;

  static OperatingSystem? fromUserAgent(String? userAgent) {
    for (final os in OperatingSystem.values) {
      if (userAgent != null && userAgent.toLowerCase().contains(os.specifierInsideUserAgent.toLowerCase())) {
        return os;
      }
    }
    return null;
  }

  static OperatingSystem? fromString(String? value) {
    if (value == null) {
      return null;
    }

    for (final os in OperatingSystem.values) {
      if (value.toLowerCase() == os.nameFormatted.toLowerCase()) {
        return os;
      }
      if (value.toLowerCase() == os.specifierInsideUserAgent.toLowerCase()) {
        return os;
      }
      if (value.toLowerCase() == os.name.toLowerCase()) {
        return os;
      }
    }

    return null;
  }
}
