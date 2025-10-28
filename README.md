# Swetrix for Flutter & Dart

A lightweight, platform-agnostic client for the [Swetrix Events API](https://docs.swetrix.com/events-api).  
Use it to track page views, custom events, heartbeats, and application errors from any Flutter or Dart application—no platform channels required.

## Features

- HTTP client built on top of `package:http` with no runtime platform code
- Automatic enrichment of events with OS, OS version, locale, country, device type, browser (web), app version & build number
- Visitor identifier persisted across sessions to keep repeat users deduplicated
- Automatically injects `User-Agent` and `X-Client-IP-Address` headers (configurable resolver) so Swetrix can identify unique visitors reliably
- Error tracking support aligned with the Swetrix dashboard
- Heartbeat scheduler to keep live visitor counters up to date
- Works with the production cloud API or self-hosted deployments

## Installation

Add the package to your Flutter (or pure Dart) project:

```yaml
dependencies:
  swetrix_flutter: ">=0.1.0"
```

or

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
import 'package:swetrix_flutter/swetrix_flutter.dart';

final swetrix = SwetrixFlutterClient(
  projectId: 'YOUR_PROJECT_ID',
  options: SwetrixOptions(apiUrl: Uri.parse('https://analytics.api.ehwplus.com/log')),
);

Future<void> trackLaunch() async {
  await swetrix.trackPageView(
    page: '/home',
    context: SwetrixContext(metadata: {'uiMode': brightness.name}),
  );
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

The `SwetrixFlutterClient` automatically:

- Collects OS, OS version, device classification (mobile/tablet/desktop), language, country and—on web builds—the active browser name.
- Pulls the app version and build number via `package_info_plus`.
- Persists a per-project visitor identifier in `SharedPreferences` so every user counts only once.
- Adds the visitor ID and device metadata to all page views, events, and error payloads, while marking the first page view as `unique`.

> **Important:** When using the lower-level `Swetrix` client directly you must provide accurate `User-Agent` and `X-Client-IP-Address` headers yourself to keep unique visitor metrics meaningful. See the [Events API reference](https://docs.swetrix.com/events-api) for full details.

By default the Flutter helper performs a single request to `https://api.ipify.org` to determine the public IP address. You can supply your own resolver if you prefer a different service.

## Advanced usage

- **Self-hosted API** – Override the endpoint via `SwetrixOptions(apiUrl: Uri.parse('https://your-host/log'))`.
- **Additional metadata** – Supply `context` or `metadata` overrides when calling `trackPageView` / `trackEvent` to extend the automatically collected fields.
- **Heartbeats** – Use `startHeartbeat()` / `stopHeartbeat()` to keep live visitor counters fresh.
- **Custom headers per call** – Supply `SwetrixRequestOptions` when sending individual events.
- **Custom client IP logic** – Pass `clientIpResolver` when constructing `SwetrixFlutterClient` to plug in your own IP detection (e.g. hitting an on-premise endpoint).
- **Custom user agent** – Provide the `userAgent` parameter if you prefer to send a hand-crafted header instead of the generated one.

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

Bug reports and feature requests are welcome via the [issue tracker](https://github.com/Swetrix/swetrix-flutter/issues).
