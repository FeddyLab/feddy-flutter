/// Feddy SDK for Flutter — feedback infrastructure for mobile apps.
///
/// Two calls cover the integration:
///
/// ```dart
/// // 1. Once at app launch:
/// Feddy.configure(apiKey: 'fed_xxxxxxxxxxxx');
///
/// // 2. After your auth handler runs:
/// Feddy.identify(userId: user.id, email: user.email, displayName: user.name);
/// ```
///
/// See README.md for the full surface (compose / list / detail /
/// roadmap views, smart review, attachments, custom-board i18n).
library feddy_flutter;

export 'src/version.dart' show sdkVersion;
