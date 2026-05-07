import 'package:feddy_flutter/feddy_flutter.dart';
import 'package:feddy_flutter/src/system_boards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setLocale(FeddyLocale.en);
    clearBoardTranslations();
  });

  tearDown(() {
    clearBoardTranslations();
  });

  group('localizedBoardName', () {
    test('returns SDK i18n for system keys (en)', () {
      expect(localizedBoardName('features'), 'Feature');
      expect(localizedBoardName('bugs'), 'Bug');
    });

    test('returns SDK i18n for system keys (ja)', () {
      setLocale(FeddyLocale.ja);
      expect(localizedBoardName('features'), '機能');
      expect(localizedBoardName('bugs'), 'バグ');
    });

    test('ignores fallbackName on system keys', () {
      setLocale(FeddyLocale.de);
      expect(
        localizedBoardName('features', 'Server English Override'),
        'Funktion',
      );
    });

    test('returns fallback for custom key', () {
      expect(
        localizedBoardName('roadmap-2026', 'Roadmap 2026'),
        'Roadmap 2026',
      );
    });

    test('capitalizes when no fallback', () {
      expect(localizedBoardName('experiments'), 'Experiments');
    });

    test('returns empty for empty key', () {
      expect(localizedBoardName(''), '');
    });
  });

  group('host boardTranslations override', () {
    test('uses host translation for current locale', () {
      setBoardTranslations({
        'roadmap-2026': {
          'en': 'Roadmap 2026',
          'ja': 'ロードマップ 2026',
        },
      });
      setLocale(FeddyLocale.ja);
      expect(
        localizedBoardName('roadmap-2026', 'Server EN'),
        'ロードマップ 2026',
      );
    });

    test('falls back to server name on missing locale', () {
      setBoardTranslations({
        'design': {'ja': 'デザイン'},
      });
      setLocale(FeddyLocale.es);
      expect(localizedBoardName('design', 'Server Design'), 'Server Design');
    });

    test('does NOT override system keys', () {
      setBoardTranslations({
        'features': {'ja': 'カスタム機能', 'en': 'My Custom'},
      });
      setLocale(FeddyLocale.ja);
      expect(localizedBoardName('features', 'Features'), '機能');
      setLocale(FeddyLocale.en);
      expect(localizedBoardName('features', 'Features'), 'Feature');
    });

    test('clearBoardTranslations wipes the table', () {
      setBoardTranslations({
        'design': {'ja': 'デザイン'},
      });
      clearBoardTranslations();
      setLocale(FeddyLocale.ja);
      expect(localizedBoardName('design', 'Design'), 'Design');
    });
  });

  group('localizeBoard', () {
    test('replaces system board name with i18n value', () {
      setLocale(FeddyLocale.es);
      final localized = localizeBoard(
        const FeedbackBoard(key: 'features', name: 'Features'),
      );
      expect(localized.name, 'Función');
    });

    test('passes custom boards through untouched', () {
      const board = FeedbackBoard(key: 'design', name: 'Design Feedback');
      expect(localizeBoard(board), board);
    });

    test('applies host translation on custom keys', () {
      setBoardTranslations({
        'roadmap-2026': {'ja': 'ロードマップ 2026'},
      });
      setLocale(FeddyLocale.ja);
      final result = localizeBoard(
        const FeedbackBoard(key: 'roadmap-2026', name: 'Roadmap 2026'),
      );
      expect(result.name, 'ロードマップ 2026');
    });
  });

  group('systemDefaultBoards', () {
    test('returns localized features + bugs in order', () {
      setLocale(FeddyLocale.fr);
      final boards = systemDefaultBoards();
      expect(boards.length, 2);
      expect(boards[0].key, 'features');
      expect(boards[0].name, 'Fonction');
      expect(boards[1].key, 'bugs');
      expect(boards[1].name, 'Bug');
    });
  });
}
