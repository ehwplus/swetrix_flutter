# Swetrix for Flutter & Dart

A lightweight, platform-agnostic client for the [Swetrix Events API](https://docs.swetrix.com/events-api).  
Use it to track page views, custom events, heartbeats, and application errors from any Flutter or Dart application—no platform channels required.

## Features

- Zero-dependency HTTP client built on top of `package:http`
- Page view and custom event helpers with metadata merging
- Error tracking support aligned with Swetrix dashboards
- Heartbeat scheduler to keep live visitor counters up to date
- Works with the production cloud API or self-hosted deployments

## Installation

Add the package to your Flutter (or pure Dart) project:

```yaml
dependencies:
  swetrix_flutter:
    git:
      url: https://github.com/ehwplus/swetrix_flutter.git
```

Then install dependencies:

```sh
flutter pub get
```

## Quick start

```dart
import 'package:swetrix/swetrix.dart';

final swetrix = Swetrix(
  projectId: 'YOUR_PROJECT_ID',
  options: SwetrixOptions(
    defaultContext: const SwetrixContext(
      locale: 'en-US',
      timezone: 'Europe/Berlin',
    ),
    requestOptions: const SwetrixRequestOptions(
      userAgent: 'MyFlutterApp/1.0.0',
      clientIpAddress: '198.51.100.18',
    ),
  ),
);

Future<void> trackLaunch() async {
  await swetrix.trackPageView(page: '/home');
  await swetrix.trackEvent(
    'AppLaunch',
    metadata: const {'build': 42, 'channel': 'stable'},
  );
}

Future<void> reportError(Object error, StackTrace stack) async {
  await swetrix.trackError(
    SwetrixErrorEvent(
      name: error.runtimeType.toString(),
      message: error.toString(),
      stackTrace: stack.toString(),
      page: '/home',
    ),
  );
}
```

> **Important:** To keep Swetrix unique visitor counts accurate you should supply the `User-Agent` and `X-Client-IP-Address` headers.  
> See the [Events API reference](https://docs.swetrix.com/events-api) for details.

## Advanced usage

- **Self-hosted API** – Pass your custom endpoint via `SwetrixOptions(apiUrl: Uri.parse('https://your-host/log'))`.
- **Default metadata** – Provide `SwetrixContext.metadata` to attach key/value pairs to all page views.
- **Heartbeats** – Call `startHeartbeat()` to schedule a keep-alive timer and `stopHeartbeat()` on teardown.
- **Custom headers per call** – Supply `SwetrixRequestOptions` when sending individual events.

## Example application

A runnable Flutter example that wires everything together lives under [`example/`](example/).  
Clone the repository and execute:

```sh
cd example
flutter run
```

## Documentation & Support

- Swetrix JS SDK (feature parity reference): <https://github.com/Swetrix/swetrix-js>
- Events API reference: <https://docs.swetrix.com/events-api>
- Swetrix integrations overview: <https://docs.swetrix.com/integrations>

Bug reports and feature requests are welcome via the [issue tracker](https://github.com/Swetrix/swetrix-dart/issues).
