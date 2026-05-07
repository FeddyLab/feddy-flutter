/// Result type for `validateApiKey`. Mirrors the discriminated union
/// in `feddy-react-native/src/api-key.ts`.
sealed class ApiKeyValidation {
  const ApiKeyValidation();
}

class ApiKeyValid extends ApiKeyValidation {
  final String value;
  const ApiKeyValid(this.value);
}

class ApiKeyInvalid extends ApiKeyValidation {
  final String reason;
  const ApiKeyInvalid(this.reason);
}

final RegExp _projectIdRegex = RegExp(r'^fed_[A-Za-z0-9]{12}$');

/// Validates a Project ID. Accepts the canonical `fed_<12 base62>`
/// shape, explicitly rejects server keys (`fed_sk_*`) so a leaked
/// secret can't ship inside a mobile binary, and explicitly rejects
/// the deprecated `fed_pk_*` form.
ApiKeyValidation validateApiKey(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const ApiKeyInvalid('Project ID is empty.');
  }
  if (trimmed.startsWith('fed_sk_')) {
    return const ApiKeyInvalid(
      'Server API keys (fed_sk_*) must not be embedded in clients. '
      'Use your Project ID (fed_xxxxxxxxxxxx) instead.',
    );
  }
  if (!_projectIdRegex.hasMatch(trimmed)) {
    return const ApiKeyInvalid(
      'Invalid Project ID. Expected format: fed_ followed by 12 alphanumeric characters.',
    );
  }
  return ApiKeyValid(trimmed);
}
