import 'package:feddy_flutter/src/api_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateApiKey', () {
    test('accepts a well-formed Project ID', () {
      final result = validateApiKey('fed_abc123def456');
      expect(result, isA<ApiKeyValid>());
      expect((result as ApiKeyValid).value, 'fed_abc123def456');
    });

    test('trims whitespace', () {
      final result = validateApiKey('  fed_abc123def456  ');
      expect((result as ApiKeyValid).value, 'fed_abc123def456');
    });

    test('rejects empty string', () {
      expect(validateApiKey(''), isA<ApiKeyInvalid>());
    });

    test('rejects whitespace-only', () {
      expect(validateApiKey('   '), isA<ApiKeyInvalid>());
    });

    test('rejects server keys (fed_sk_*)', () {
      final result = validateApiKey('fed_sk_abc123def456');
      expect(result, isA<ApiKeyInvalid>());
      expect(
        (result as ApiKeyInvalid).reason,
        contains('Server API keys'),
      );
    });

    test('rejects deprecated fed_pk_* form', () {
      expect(
        validateApiKey('fed_pk_abc123def456'),
        isA<ApiKeyInvalid>(),
      );
    });

    test('rejects wrong prefix', () {
      expect(validateApiKey('foo_abc123def456'), isA<ApiKeyInvalid>());
    });

    test('rejects too short', () {
      expect(validateApiKey('fed_abc'), isA<ApiKeyInvalid>());
    });

    test('rejects non-alphanumeric body', () {
      expect(validateApiKey('fed_abc-23def456'), isA<ApiKeyInvalid>());
    });
  });
}
