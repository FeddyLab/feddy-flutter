# Changelog

All notable changes to this package will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] - 2026-05-08

### Added
- `Feddy.fetchRequests` / `Feddy.fetchRequest` / `Feddy.upvote` / `Feddy.fetchComments` / `Feddy.addComment` — public read-side methods for building custom roadmap UIs
- `RequestDetailView` now renders attached images in a tap-to-zoom grid
- Optimistic upvote with automatic rollback on failure across `RequestListView` and `RequestDetailView`

### Fixed
- Upvote endpoint corrected from `/votes` to `/vote`; previously every upvote attempt 404'd silently
- `fetchRequests` / `fetchRequest` now send the `as_external_user_id` / `as_anonymous_token` query so the per-item `voted` flag reflects the current user
- `addComment` / `upvote` / `fetchComments` reject empty / whitespace-only request ids before the network call
- `Feddy.addComment` now trims and rejects empty bodies before any network call

## [0.2.0] - 2026-05-07

### Added
- Automatic subscription detection on iOS via `SK2Transaction.transactions()` (StoreKit 2)
- Automatic subscription detection on Android via Play Billing `purchaseStream` + `restorePurchases()`
- `Feddy.refreshSubscription()` re-runs detection after a purchase or restore

### Changed
- `Feddy.configure(autoDetectSubscription:)` defaults to `true` and now actively detects entitlements; pass `false` to disable

## [0.1.0] - 2026-05-07

Initial public release. Day-one parity with the iOS / React Native
siblings — same server protocol, same 5-locale catalog, same
fire-and-forget API style.

### Added
- `Feddy.configure(apiKey:)` + `Feddy.identify(...)` + `Feddy.submitRequest(...)` + `Feddy.openFeedback(...)` + `Feddy.reset()`
- Drop-in Material widgets: `RequestListView` / `RoadmapView` / `RequestDetailView` / `FeedbackComposeView` / `SmartReviewSheet`
- `Feddy.requestReviewIfAppropriate(...)` with the 4-gate engine (install age / sessions / cooldown / yearly cap)
- Manual `Feddy.setSubscription(...)` override (auto-detect IAP reserved for v0.2)
- 5-locale i18n catalog (en / es / ja / de / fr) auto-detected from device
- `boardTranslations` injection for host-supplied custom-key labels
- Image attachments via `image_picker` + auto-compression to ≤800 KB
- Offline submit queue persisted across launches (50 cap / 5 retries)
- Server-driven Powered by Feddy footer rendered by `PoweredByBadge`
