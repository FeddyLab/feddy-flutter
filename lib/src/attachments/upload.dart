import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../client.dart';
import '../feddy_error.dart';

/// Cap each attachment at ~800 KB so a 3-image batch stays well under
/// Cloudflare Worker's 100 MB body limit + keeps R2 GET latency low
/// for end-user roadmap browsing. Mirrors the iOS / RN compression
/// budget.
const int _kMaxBytes = 800 * 1024;

/// JPEG quality steps to try when compressing. Starts with 85 (typical
/// no-loss-visible) and steps down until the encoded payload fits
/// under [_kMaxBytes]. iOS / RN use the same ladder.
const List<int> _kQualityLadder = [85, 70, 55, 40];

/// Compress + sign + PUT one image to R2. Returns the attachment
/// `key` the server hands back, which the caller appends to its
/// `submitRequest` payload's `attachment_keys` array.
///
/// Throws [FeddyError] on any failure — the caller (compose form)
/// catches per-image so a partial batch still creates the request.
Future<String> uploadAttachment(FeddyClient client, String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  final compressed = await _compressJpeg(bytes);

  final signResponse = await client.post('/v1/attachments/sign', {
    'content_type': 'image/jpeg',
    'size': compressed.length,
  });
  final uploadUrl = signResponse?['upload_url'] as String?;
  final key = signResponse?['key'] as String?;
  if (uploadUrl == null || key == null) {
    throw const FeddyError(
      code: FeddyErrorCode.decoding,
      message: 'Sign response missing upload_url / key',
    );
  }

  final put = await http.put(
    Uri.parse(uploadUrl),
    headers: {'Content-Type': 'image/jpeg'},
    body: compressed,
  );
  if (put.statusCode < 200 || put.statusCode >= 300) {
    throw FeddyError(
      code: FeddyErrorCode.http,
      status: put.statusCode,
      message: 'R2 PUT failed (${put.statusCode})',
    );
  }
  return key;
}

Future<Uint8List> _compressJpeg(Uint8List raw) async {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw const FeddyError(
      code: FeddyErrorCode.invalidPayload,
      message: 'Could not decode image',
    );
  }
  // First-pass downscale: cap longest edge at 1920 px. Keeps detail
  // for screenshot use cases while ditching the 4032×3024 overhead a
  // raw camera capture brings.
  final scaled = decoded.width > 1920 || decoded.height > 1920
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1920 : null,
          height: decoded.height > decoded.width ? 1920 : null,
        )
      : decoded;
  for (final quality in _kQualityLadder) {
    final encoded = img.encodeJpg(scaled, quality: quality);
    if (encoded.length <= _kMaxBytes) return encoded;
  }
  // Final fallback: lowest-quality version. Server enforces its own
  // upper bound; if this still exceeds [_kMaxBytes] the sign call
  // will reject with `invalid_payload` and we'll surface that.
  return img.encodeJpg(scaled, quality: _kQualityLadder.last);
}
