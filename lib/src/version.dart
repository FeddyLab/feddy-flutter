/// Bumped on every release. Sent as `X-Feddy-Sdk-Version` on every
/// outbound request and read by `feddy-api/src/shared/sdk-usage.ts`
/// to populate `workspace_sdk_usage`.
const String sdkVersion = '0.1.0';

/// Stable platform identifier sent as `X-Feddy-Sdk-Platform`. Always
/// `flutter` for this SDK; the iOS / Android / RN siblings have their
/// own constants.
const String sdkPlatform = 'flutter';
