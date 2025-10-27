import 'package:meta/meta.dart';

/// Optional performance metrics that can be attached to page view events.
@immutable
class SwetrixPerformanceMetrics {
  const SwetrixPerformanceMetrics({
    this.dns,
    this.tls,
    this.connection,
    this.response,
    this.render,
    this.domLoad,
    this.pageLoad,
    this.timeToFirstByte,
  });

  final num? dns;
  final num? tls;
  final num? connection;
  final num? response;
  final num? render;
  final num? domLoad;
  final num? pageLoad;
  final num? timeToFirstByte;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      if (dns != null) 'dns': dns,
      if (tls != null) 'tls': tls,
      if (connection != null) 'conn': connection,
      if (response != null) 'response': response,
      if (render != null) 'render': render,
      if (domLoad != null) 'dom_load': domLoad,
      if (pageLoad != null) 'page_load': pageLoad,
      if (timeToFirstByte != null) 'ttfb': timeToFirstByte,
    };
  }
}
