/// Error codes returned by the SDK. Mirrors `FeddyErrorCode` in
/// `feddy-react-native/src/types.ts`.
enum FeddyErrorCode {
  notConfigured,
  invalidApiKey,
  invalidPayload,
  network,
  http,
  decoding,
}

class FeddyError implements Exception {
  final FeddyErrorCode code;
  final String message;
  final int? status;
  final String? serverCode;

  const FeddyError({
    required this.code,
    required this.message,
    this.status,
    this.serverCode,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (status != null) parts.add('HTTP $status');
    if (serverCode != null) parts.add('[$serverCode]');
    parts.add(message);
    return 'FeddyError(${code.name}): ${parts.join(' ')}';
  }
}
