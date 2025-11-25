## 0.1.3

- Add `IpAddressCacheRule` test-wise with default value `never`. I want to evaluate if the unique visitors are tracked more reliable.
- Refactor: Lint warnings fixed

## 0.1.1

- Initial public release of the Swetrix Events API client for Flutter/Dart.
- Added `SwetrixFlutterClient` helper that auto-collects OS, OS version, device type, language, country, browser (web), app version, and build number.
- Automatically injects `User-Agent` and `X-Client-IP-Address` headers (with configurable resolver) so Swetrix deduplicates visitors out of the box.
- Persist visitor identifiers with `SharedPreferences` to keep unique user counts stable across sessions.
- Supports page view, custom event, error, and heartbeat tracking with automatic visitor metadata and optional self-hosted endpoints.
- Ships with unit tests and an updated Flutter example leveraging the new helper.
