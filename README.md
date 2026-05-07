# Feddy SDK for Flutter

> **Beta Notice**: This SDK is currently in beta (v0.1.0). The API may change before the 1.0 release.

Feddy gives Flutter apps a feedback loop that doesn't get in the way: a smart-review prompt that captures low ratings privately while routing 4-5 star moments to the App Store / Play Store, paid-user signals via in-app purchase auto-detection, and drop-in Material widgets for browsing the public roadmap.

## Installation

```sh
flutter pub add feddy_flutter
```

## Quick Start

### 1. Setup

Configure the SDK once at app launch with your **Project ID** (`fed_xxxxxxxxxxxx`, copied from your Feddy dashboard):

```dart
import 'package:feddy_flutter/feddy_flutter.dart';

void main() {
  Feddy.configure(apiKey: 'fed_xxxxxxxxxxxx');
  runApp(const MyApp());
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

(More surface — list / roadmap / smart review / custom boards / subscription — coming as v0.1.0 ships its full parity with the iOS and React Native SDKs.)

## Requirements

- Flutter 3.10+
- Dart 3.0+
- iOS 12+ / Android API 21+

## Features

- **Smart Review** — turn 4-5 star moments into App Store reviews and 1-3 star moments into private feedback.
- **Image Attachments** — up to 3 photos per request, auto-compressed and uploaded directly to R2.
- **Anonymous Fallback** — writes attribute correctly even before the host app calls `identify()`.
- **5 Locales** — en / es / ja / de / fr auto-detected from the device.

## License

MIT — see [LICENSE](./LICENSE).

## Support

- Dashboard: <https://feddy.app>
- Issues: <https://github.com/FeddyLab/feddy-flutter/issues>
