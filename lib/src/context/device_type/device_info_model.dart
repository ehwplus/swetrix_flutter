import 'package:meta/meta.dart';

@immutable
class SwetrixDeviceInfo {
  const SwetrixDeviceInfo({
    this.deviceModel,
    this.manufacturer,
    this.os,
    this.osVersion,
    this.browserName,
  });

  final String? deviceModel;
  final String? manufacturer;
  final String? os;
  final String? osVersion;
  final String? browserName;
}
