import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_key.dart';
import 'feddy_error.dart';
import 'headers.dart';

const String _defaultBaseUrl = 'https://api.feddy.app';

/// Internal HTTP client — wraps `package:http` with the SDK's
/// authorization + census headers and the `feddy-api`
/// `apiError` envelope shape (`{ code, message, details? }`).
class FeddyClient {
  final String apiKey;
  final Uri baseUrl;
  final bool autoDetectSubscription;
  final http.Client httpClient;

  FeddyClient._({
    required this.apiKey,
    required this.baseUrl,
    required this.autoDetectSubscription,
    required this.httpClient,
  });

  /// Validate inputs + construct. Throws `FeddyError` with
  /// `invalidApiKey` when the apiKey is empty / wrong shape /
  /// a server key.
  static FeddyClient create({
    required String apiKey,
    String? baseUrl,
    bool autoDetectSubscription = true,
    http.Client? httpClient,
  }) {
    final validation = validateApiKey(apiKey);
    if (validation is ApiKeyInvalid) {
      throw FeddyError(
        code: FeddyErrorCode.invalidApiKey,
        message: validation.reason,
      );
    }
    final valid = validation as ApiKeyValid;
    return FeddyClient._(
      apiKey: valid.value,
      baseUrl: Uri.parse(baseUrl ?? _defaultBaseUrl),
      autoDetectSubscription: autoDetectSubscription,
      httpClient: httpClient ?? http.Client(),
    );
  }

  Uri _buildUrl(String path, {Map<String, String?>? query}) {
    final qp = <String, String>{};
    if (query != null) {
      for (final entry in query.entries) {
        final v = entry.value;
        if (v != null && v.isNotEmpty) qp[entry.key] = v;
      }
    }
    return baseUrl.replace(
      path: path,
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String?>? query,
  }) async {
    final url = _buildUrl(path, query: query);
    final headers = await buildHeaders(apiKey);
    final http.Response response;
    try {
      response = await httpClient.get(url, headers: headers);
    } catch (e) {
      throw FeddyError(
        code: FeddyErrorCode.network,
        message: e.toString(),
      );
    }
    return _decode(response, path);
  }

  Future<Map<String, dynamic>?> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = _buildUrl(path);
    final headers = await buildHeaders(apiKey);
    headers['Content-Type'] = 'application/json';
    final encoded = jsonEncode(body);
    final http.Response response;
    try {
      response = await httpClient.post(url, headers: headers, body: encoded);
    } catch (e) {
      throw FeddyError(
        code: FeddyErrorCode.network,
        message: e.toString(),
      );
    }
    return _decode(response, path);
  }

  /// Lower-level POST that takes already-encoded JSON bytes. Used by
  /// the offline-queue replay path where the body was serialized once
  /// at enqueue time and shouldn't be re-encoded on every retry.
  Future<Map<String, dynamic>?> postRaw(String path, String encodedBody) async {
    final url = _buildUrl(path);
    final headers = await buildHeaders(apiKey);
    headers['Content-Type'] = 'application/json';
    final http.Response response;
    try {
      response =
          await httpClient.post(url, headers: headers, body: encodedBody);
    } catch (e) {
      throw FeddyError(
        code: FeddyErrorCode.network,
        message: e.toString(),
      );
    }
    return _decode(response, path);
  }

  Map<String, dynamic>? _decode(http.Response response, String path) {
    final text = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic>? envelope;
      try {
        envelope =
            text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        envelope = null;
      }
      throw FeddyError(
        code: FeddyErrorCode.http,
        status: response.statusCode,
        serverCode: envelope?['code'] as String?,
        message: envelope?['message'] as String? ??
            'HTTP ${response.statusCode} from $path',
      );
    }
    if (text.isEmpty) return null;
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
      // Server only returns objects on the contracted endpoints.
      return {'value': parsed};
    } catch (e) {
      throw FeddyError(
        code: FeddyErrorCode.decoding,
        message: e.toString(),
      );
    }
  }

  void close() => httpClient.close();
}
