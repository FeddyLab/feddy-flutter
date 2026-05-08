# Feddy SDK for Flutter

> **Beta Notice**: This SDK is currently in beta (v0.3.0). The API may change before the 1.0 release.

Feddy gives Flutter apps a feedback loop that doesn't get in the way: a smart-review prompt that captures low ratings privately while routing 4-5 star moments to the App Store / Play Store, paid-user signals you push from your subscription source-of-truth, and drop-in Material widgets for the public roadmap.

## Installation

```sh
flutter pub add feddy_flutter
```

## Quick Start

### 1. Setup

Configure the SDK once at app launch with your **Project ID** (`fed_xxxxxxxxxxxx`, copied from your Feddy dashboard) and mount `FeddyProvider` at the root of your app:

```dart
import 'package:feddy_flutter/feddy_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  Feddy.configure(apiKey: 'fed_xxxxxxxxxxxx');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const FeddyProvider(child: HomePage()),
    );
  }
}
```

### 2. Identify Users

Call `Feddy.identify(...)` after your auth handler runs so feedback rows in the dashboard carry user attribution:

```dart
Feddy.identify(
  userId: user.id,
  email: user.email,
  displayName: user.name,
);
```

### 3. Open the Feedback Modal

```dart
Feddy.openFeedback(boardKey: 'features');
```

### 4. Browse Feedback + Roadmap

Drop the bundled views into your app's navigation:

```dart
Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const RequestListView()),
);
```

```dart
Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const RoadmapView()),
);
```

### 5. Smart Review

Call this from any "user just had a good moment" hook — onboarding completed, save succeeded, level cleared, etc:

```dart
Feddy.requestReviewIfAppropriate(trigger: 'task_50_complete');
```

The SDK's built-in gates decide whether to actually present the prompt (≥7 days install age, ≥5 sessions, ≥90d cooldown, ≤3 prompts per 365d window). 4-5 stars route to the system review prompt; 1-3 stars route to the built-in compose modal so the feedback is captured privately instead of as a public 1-3 star App Store review.

## Submit Feedback

### Programmatic Submit

Submit feedback without showing the modal — useful for custom UIs:

```dart
Feddy.submitRequest(
  title: 'Add dark mode',
  description: 'Hard to read at night.',
  boardKey: 'features',
);
```

Fire-and-forget. Network failures are queued and replayed on the next `configure(...)` call.

### Direct Compose Widget

Mount the compose form yourself for embedded use cases:

```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const FeedbackComposeView(),
);
```

## Show Roadmap

`RoadmapView` renders three tabs (Planned / In Progress / Completed) populated by `GET /v1/requests?status=…`. Vote / browse / comment all work out of the box.

```dart
Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const RoadmapView()),
);
```

## Advanced Usage

### Anonymous Tracking

`Feddy.submitRequest()` works even before `identify()` — the SDK persists a per-install anonymous token so writes still attribute correctly. Once `identify(...)` runs, the same install's prior anonymous writes are linked to the identified user server-side.

### Logout

```dart
Feddy.reset();
```

Clears the last identified user, manual subscription override, and cached server capabilities. The anonymous token is intentionally preserved so any feedback the user submitted before login still links correctly.

### Subscription State

`Feddy.configure(...)` enables automatic subscription detection by default — no product IDs required:

- **iOS**: reads `SK2Transaction.transactions()` (StoreKit 2)
- **Android**: subscribes to Play Billing's `purchaseStream` and triggers `restorePurchases()`

The detected snapshot is attached to the next `Feddy.identify(...)` call. Call `Feddy.refreshSubscription()` after a purchase / restore to re-read state. Pass `autoDetectSubscription: false` to disable.

Limitations:

- **Android** subscriptions surface no expiration timestamp (`expiresAt` is always `null`); Play Billing's client-side API does not expose it
- Trial / introductory offer detection is not performed; not-yet-expired entitlements are reported as `active`

If your source-of-truth for paid state is RevenueCat, Adapty, or your own server, push the snapshot manually — manual overrides always win:

```dart
Feddy.setSubscription(const Subscription(
  isPaid: true,
  status: SubscriptionStatus.active,
  productId: 'com.foo.pro_yearly',
  expiresAt: '2027-01-01T00:00:00Z',
));

// Pass null to clear the override.
Feddy.setSubscription(null);
```

Both manual and auto values persist across launches via `shared_preferences`; the next `Feddy.identify(...)` call attaches whichever takes precedence automatically.

### Custom Boards & i18n

The two SDK-shipped system boards (`features` / `bugs`) come pre-translated in 5 locales (en / es / ja / de / fr) and are picked automatically based on the device locale. The bundled views fetch the workspace's full board set from `GET /v1/boards` (1 h cached) so any custom board you create in the dashboard appears without redeploying the app:

```dart
const RequestListView();    // boards fetched in the background
const RoadmapView();
```

For **custom boards**, supply per-locale display names via `boardTranslations` so each device locale renders the right label:

```dart
Feddy.configure(
  apiKey: 'fed_xxxxxxxxxxxx',
  boardTranslations: const {
    'roadmap-2026': {
      'en': 'Roadmap 2026',
      'ja': 'ロードマップ 2026',
      'es': 'Hoja de ruta 2026',
    },
    'design': {'ja': 'デザインフィードバック'},
  },
);
```

Resolution order for any custom board key:

1. `boardTranslations[key][deviceLocale]` if set
2. The server's `board.name` (whatever the admin typed in the dashboard)
3. Capitalized key as a last-ditch label

System keys (`features` / `bugs`) always use the SDK's bundled translations — they are intentionally not overridable so first-party UI stays consistent across SDK platforms.

If your app already has its own i18n system and you want to bypass `fetchBoards`, pass an explicit `boards` parameter — the view will skip the network call entirely:

```dart
RequestListView(
  boards: [
    FeedbackBoard(key: 'features', name: t('feedback.boards.features')),
    FeedbackBoard(key: 'bugs', name: t('feedback.boards.bugs')),
    FeedbackBoard(key: 'design', name: t('feedback.boards.design')),
  ],
);
```

```dart
final boards = await Feddy.fetchBoards();    // for fully custom UIs (coming with read API in v0.x)
```

## Requirements

- Flutter 3.10+
- Dart 3.0+
- iOS 12+ / Android API 21+

## Features

- **Smart Review** — turn 4-5 star moments into App Store reviews and 1-3 star moments into private feedback.
- **Image Attachments** — up to 3 photos per request, auto-compressed and uploaded directly to R2.
- **Anonymous Fallback** — writes attribute correctly even before the host app calls `identify()`.
- **Offline Queue** — submits made while offline are persisted and replayed on the next `configure()`.
- **5 Locales** — en / es / ja / de / fr auto-detected from the device.

## License

MIT — see [LICENSE](./LICENSE).

## Support

- Dashboard: <https://feddy.app>
- Issues: <https://github.com/FeddyLab/feddy-flutter/issues>
