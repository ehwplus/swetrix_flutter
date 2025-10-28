import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

String resolveDeviceType({ui.PlatformDispatcher? dispatcher}) {
  if (dispatcher == null) {
    WidgetsFlutterBinding.ensureInitialized();
    dispatcher = WidgetsBinding.instance.platformDispatcher;
  }

  // Try first explicit platform classification.
  if (kIsWeb) {
    return _classifyByWidth(dispatcher);
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.fuchsia:
      return 'desktop';
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      final widthType = _classifyByWidth(dispatcher);
      return widthType == 'desktop' ? 'tablet' : widthType;
  }
}

String _classifyByWidth(ui.PlatformDispatcher dispatcher) {
  final view = dispatcher.implicitView ??
      (dispatcher.views.isNotEmpty ? dispatcher.views.first : null);
  if (view == null) {
    return 'unknown';
  }

  final logicalWidth =
      view.physicalSize.width / max(view.devicePixelRatio, 1.0);
  if (logicalWidth >= 1024) {
    return 'desktop';
  }
  if (logicalWidth >= 700) {
    return 'tablet';
  }
  return 'mobile';
}
