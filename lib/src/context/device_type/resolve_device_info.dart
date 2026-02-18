import 'device_info_impl_stub.dart'
    if (dart.library.io) 'device_info_impl_io.dart'
    if (dart.library.html) 'device_info_impl_web.dart';
import 'device_info_model.dart';

Future<SwetrixDeviceInfo> resolveDeviceInfo() => resolveDeviceInfoForPlatform();
