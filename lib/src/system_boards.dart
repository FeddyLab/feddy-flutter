import 'i18n/i18n.dart';
import 'types.dart';

/// Display-name translations for **custom** board keys — anything
/// beyond the two SDK-shipped system boards (`features` / `bugs`).
/// Keyed by board key, then by 2-letter locale code (`en` / `es` /
/// `ja` / `de` / `fr`).
typedef BoardTranslations = Map<String, Map<String, String>>;

/// Board keys the SDK ships first-party translations for. Any board
/// with a key in this set has its display name pulled from the SDK's
/// bundled i18n catalog and is **not** overridable by the host —
/// keeps first-party UI consistent across SDK platforms.
const Set<String> kSystemBoardKeys = {'features', 'bugs'};

BoardTranslations _hostBoardTranslations =
    const <String, Map<String, String>>{};

void setBoardTranslations(BoardTranslations? value) {
  _hostBoardTranslations = value ?? const <String, Map<String, String>>{};
}

void clearBoardTranslations() {
  _hostBoardTranslations = const <String, Map<String, String>>{};
}

BoardTranslations getBoardTranslations() => _hostBoardTranslations;

/// Lookup the host translation for a custom key in the current
/// device locale. Returns `null` when no entry / locale is missing.
String? hostBoardTranslation(String key) {
  final entry = _hostBoardTranslations[key];
  if (entry == null) return null;
  final code = currentLocale().name;
  final value = entry[code];
  if (value == null || value.isEmpty) return null;
  return value;
}

/// Display-name resolution for a board key. Mirrors the React Native
/// SDK's `localizedBoardName` precedence so cross-SDK behaviour is
/// identical:
///
/// 1. SDK system key → bundled catalog (`feddy.compose.board.<key>`).
///    Locked; host overrides ignored.
/// 2. Host translation for `key` at the current device locale.
/// 3. `fallbackName` — typically the server's `board.name`.
/// 4. Capitalized key as a last-ditch label.
String localizedBoardName(String key, [String? fallbackName]) {
  if (kSystemBoardKeys.contains(key)) {
    return t('board.$key');
  }
  final host = hostBoardTranslation(key);
  if (host != null) return host;
  if (fallbackName != null && fallbackName.isNotEmpty) return fallbackName;
  if (key.isEmpty) return '';
  return '${key.substring(0, 1).toUpperCase()}${key.substring(1)}';
}

/// Re-localizes a board's name when its key is a known system board
/// or has a host translation. Custom boards without translations are
/// returned untouched.
FeedbackBoard localizeBoard(FeedbackBoard board) {
  final resolved = localizedBoardName(board.key, board.name);
  if (resolved == board.name) return board;
  return FeedbackBoard(key: board.key, name: resolved);
}

/// The two boards every Feddy workspace ships with, with names
/// pulled from the SDK's bundled localization catalog.
List<FeedbackBoard> systemDefaultBoards() => [
      FeedbackBoard(key: 'features', name: t('board.features')),
      FeedbackBoard(key: 'bugs', name: t('board.bugs')),
    ];
