import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'version.dart';

const String _unknown = 'unknown';

/// Cross-SDK census headers. Source-of-truth for the field names is
/// `feddy-api/src/shared/sdk-usage.ts`. Identical 9-field shape as iOS
/// + RN; the only field that differs is `X-Feddy-Sdk-Platform` which
/// is hardcoded to `flutter` here.
///
/// Resolved lazily once per process — package_info / device_info both
/// hit the platform channel which is async, so we cache after first
/// successful resolution.
class _Cache {
  String appId = _unknown;
  String appVersion = _unknown;
  String appBuild = _unknown;
  String deviceModel = _unknown;
  String deviceManufacturer = _unknown;
  bool resolved = false;
}

final _Cache _cache = _Cache();

Future<void> _ensureResolved() async {
  if (_cache.resolved) return;
  try {
    final pkg = await PackageInfo.fromPlatform();
    _cache.appId = pkg.packageName.isEmpty ? _unknown : pkg.packageName;
    _cache.appVersion = pkg.version.isEmpty ? _unknown : pkg.version;
    _cache.appBuild = pkg.buildNumber.isEmpty ? _unknown : pkg.buildNumber;
  } catch (_) {
    // Stay on unknowns; server tolerates these.
  }
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      _cache.deviceModel = ios.model.isEmpty ? _unknown : ios.model;
      _cache.deviceManufacturer = 'Apple';
    } else if (Platform.isAndroid) {
      final android = await info.androidInfo;
      _cache.deviceModel = android.model.isEmpty ? _unknown : android.model;
      _cache.deviceManufacturer =
          android.manufacturer.isEmpty ? _unknown : android.manufacturer;
    }
  } catch (_) {
    // Stay on unknowns.
  }
  _cache.resolved = true;
}

String _osName() {
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  return Platform.operatingSystem;
}

String _osVersion() {
  return Platform.operatingSystemVersion;
}

String _locale() {
  final locale = PlatformDispatcher.instance.locale;
  final tag = locale.toLanguageTag();
  return tag.isEmpty ? _unknown : tag;
}

/// Build the standard outbound headers for a request. Caller is
/// responsible for setting `Content-Type` on POST bodies.
Future<Map<String, String>> buildHeaders(String apiKey) async {
  await _ensureResolved();
  return {
    'Accept': 'application/json',
    'Authorization': 'Bearer $apiKey',
    'User-Agent': 'Feddy-Flutter/$sdkVersion (${_osName()})',
    'X-Feddy-Sdk-Platform': sdkPlatform,
    'X-Feddy-Sdk-Version': sdkVersion,
    'X-Feddy-App-Id': _cache.appId,
    'X-Feddy-App-Version': _cache.appVersion,
    'X-Feddy-App-Build': _cache.appBuild,
    'X-Feddy-Os-Name': _osName(),
    'X-Feddy-Os-Version': _osVersion(),
    'X-Feddy-Device-Model': _cache.deviceModel,
    'X-Feddy-Device-Manufacturer': _cache.deviceManufacturer,
    'X-Feddy-Locale': _locale(),
  };
}

/// Test-only — wipe the resolved cache so a follow-up `buildHeaders`
/// re-reads from the platform channels.
void resetHeaderCacheForTesting() {
  _cache.appId = _unknown;
  _cache.appVersion = _unknown;
  _cache.appBuild = _unknown;
  _cache.deviceModel = _unknown;
  _cache.deviceManufacturer = _unknown;
  _cache.resolved = false;
}
