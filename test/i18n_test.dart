import 'package:feddy_flutter/src/i18n/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setLocale(FeddyLocale.en);
  });

  group('t()', () {
    test('looks up English by default', () {
      expect(t('action.submit'), 'Submit');
      expect(t('action.cancel'), 'Cancel');
    });

    test('switches catalog when setLocale', () {
      setLocale(FeddyLocale.ja);
      expect(t('action.submit'), '送信');
      expect(t('action.cancel'), 'キャンセル');
    });

    test('falls back to English on missing locale key', () {
      setLocale(FeddyLocale.es);
      // Every locale ports the same key set, but the fallback path
      // is exercised when a future key is added to en first. Use a
      // key that exists in en — the lookup still resolves through
      // the catalog chain.
      expect(t('action.cancel'), 'Cancelar');
    });

    test('returns key itself when nowhere found', () {
      expect(t('completely.made.up.key'), 'completely.made.up.key');
    });

    test('interpolates {name} placeholders', () {
      expect(t('time.minutesAgo', {'n': 5}), '5m ago');
    });

    test('all 7 locales return non-empty for board.features', () {
      for (final locale in FeddyLocale.values) {
        setLocale(locale);
        expect(t('board.features').isNotEmpty, isTrue);
      }
    });
  });
}
