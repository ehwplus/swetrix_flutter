String resolveTimezone() {
  try {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${DateTime.now().timeZoneName} ($sign$hours:$minutes)';
  } catch (_) {
    return DateTime.now().timeZoneName;
  }
}
