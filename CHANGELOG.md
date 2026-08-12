## 0.2.1

- Honour per-call `profileId` and caller `metadata` on `SwetrixFlutterClient.trackPageView` / `trackEvent` (previously shadowed or dropped).
- Mark only the first pageview as `unique`, matching the documented CE unique-visitor behaviour.
- Attach device/app metadata to custom events, not only pageviews.
- Keep caller metadata on `trackError` and merge context metadata into custom events.
- Compose `User-Agent` and `X-Client-IP-Address` for scheduled heartbeats (required for self-hosted / community edition attribution).
- Do not queue CE `403` unique / heartbeat-before-session responses for retry.
- Classify web user agents by specific tokens so empty Windows specifiers no longer match every UA.
- Drop per-event `userAgent` debug prints.

## 0.2.0

- Add Swetrix v5 `profileId` support in `SwetrixOptions` and per-call overrides for pageviews, custom events, and heartbeats.
- Add feature flag and experiment APIs:
  - `getFeatureFlags`, `getFeatureFlag`, `clearFeatureFlagsCache`
  - `getExperiments`, `getExperiment`, `clearExperimentsCache`
- Add `getProfileId` and `getSessionId` helpers in the low-level `Swetrix` client.
- Improve MAU tracking defaults in `SwetrixFlutterClient` by falling back to persisted visitor IDs as `profileId`.
- Add in-memory event queue with retry (`queueFailedRequests`, `maxQueueSize`, `queueRetryInterval`) and `flushQueue()` support.
- Improve user agent generation: use real browser UA on web (`navigator.userAgent`) and parser-friendly macOS UA format.
- Improve locale attribution: resolve locale from platform/browser (`Platform.localeName` / `navigator.language`) and normalise tags (e.g. `de_DE.UTF-8` -> `de-DE`).
- Extend tests for profile ID payloads, feature flag caching, and new API methods.

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
