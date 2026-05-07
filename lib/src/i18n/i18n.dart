import 'dart:ui' show PlatformDispatcher;

import 'de.dart' show de;
import 'en.dart' show en;
import 'es.dart' show es;
import 'fr.dart' show fr;
import 'ja.dart' show ja;

/// The five locales Feddy ships first-party translations for.
/// Mirrors `feddy-react-native/src/i18n/` and
/// `feddy-ios/Sources/Feddy/Resources/Localizable.xcstrings`.
enum FeddyLocale { en, es, ja, de, fr }

const Map<FeddyLocale, Map<String, String>> _catalogs = {
  FeddyLocale.en: en,
  FeddyLocale.es: es,
  FeddyLocale.ja: ja,
  FeddyLocale.de: de,
  FeddyLocale.fr: fr,
};

FeddyLocale? _override;

/// Override the locale used by `t(...)`. Useful for tests and for
/// host apps that follow an in-app locale picker rather than the
/// device locale. Pass `null` to re-detect from the system on the
/// next `t()` call.
void setLocale(FeddyLocale? locale) {
  _override = locale;
}

/// Current locale that `t(...)` will resolve to. Reads
/// `PlatformDispatcher.instance.locale.languageCode` on first access
/// and matches it against the 5 supported locales; falls back to
/// `en` when no match.
FeddyLocale currentLocale() {
  if (_override != null) return _override!;
  final code = PlatformDispatcher.instance.locale.languageCode;
  switch (code) {
    case 'es':
      return FeddyLocale.es;
    case 'ja':
      return FeddyLocale.ja;
    case 'de':
      return FeddyLocale.de;
    case 'fr':
      return FeddyLocale.fr;
    default:
      return FeddyLocale.en;
  }
}

/// Look up a localized string by key. Falls back to English when the
/// current locale's catalog is missing the key, then to the key
/// itself if even English is missing — surfaces typos during
/// development rather than silently rendering an empty string.
///
/// Supports `{name}` placeholder interpolation via the `params` map.
String t(String key, [Map<String, Object?> params = const {}]) {
  final catalog = _catalogs[currentLocale()] ?? en;
  final template = catalog[key] ?? en[key] ?? key;
  if (params.isEmpty) return template;
  return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final value = params[m.group(1)];
    return value == null ? m.group(0)! : '$value';
  });
}
