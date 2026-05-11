import 'dart:ui' show PlatformDispatcher;

import 'de.dart' show de;
import 'en.dart' show en;
import 'es.dart' show es;
import 'fr.dart' show fr;
import 'ja.dart' show ja;
import 'zh_hans.dart' show zhHans;
import 'zh_hant.dart' show zhHant;

/// The seven locales Feddy ships first-party translations for.
/// Mirrors `feddy-react-native/src/i18n/` and
/// `feddy-ios/Sources/Feddy/Resources/Localizable.xcstrings`.
enum FeddyLocale { en, zhHans, zhHant, es, ja, de, fr }

const Map<FeddyLocale, Map<String, String>> _catalogs = {
  FeddyLocale.en: en,
  FeddyLocale.zhHans: zhHans,
  FeddyLocale.zhHant: zhHant,
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

/// Current locale that `t(...)` will resolve to. Reads the device
/// locale via `PlatformDispatcher` on every call (so a system locale
/// change between calls is picked up immediately) and matches it
/// against the seven supported locales; falls back to `en` when no
/// match.
///
/// Chinese is resolved via `scriptCode` first (`Hans` / `Hant`); when
/// the OS doesn't report one (older Android devices in particular),
/// `countryCode` is used as a fallback — `CN` / `SG` → Simplified,
/// `TW` / `HK` / `MO` → Traditional.
/// Ordered list of locale code strings to try when looking up host
/// translations for the current device locale. Most locales return a
/// single code (`en` / `es` / `ja` / `de` / `fr`). Chinese returns
/// the variant-specific code first and falls back to a plain `zh` so
/// hosts can ship either variant-specific or shared Chinese strings.
List<String> currentLocaleCodes() {
  switch (currentLocale()) {
    case FeddyLocale.zhHans:
      return const ['zh-Hans', 'zh'];
    case FeddyLocale.zhHant:
      return const ['zh-Hant', 'zh'];
    case FeddyLocale.en:
      return const ['en'];
    case FeddyLocale.es:
      return const ['es'];
    case FeddyLocale.ja:
      return const ['ja'];
    case FeddyLocale.de:
      return const ['de'];
    case FeddyLocale.fr:
      return const ['fr'];
  }
}

FeddyLocale currentLocale() {
  if (_override != null) return _override!;
  final locale = PlatformDispatcher.instance.locale;
  final code = locale.languageCode;
  if (code == 'zh') {
    final script = locale.scriptCode;
    if (script == 'Hans') return FeddyLocale.zhHans;
    if (script == 'Hant') return FeddyLocale.zhHant;
    final country = locale.countryCode;
    if (country == 'TW' || country == 'HK' || country == 'MO') {
      return FeddyLocale.zhHant;
    }
    return FeddyLocale.zhHans;
  }
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
