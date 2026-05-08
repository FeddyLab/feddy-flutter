import '../client.dart';
import '../feddy_error.dart';
import '../identity.dart';
import '../types.dart';

/// Build the `as_external_user_id` / `as_anonymous_token` query pair
/// the read endpoints use to compute the per-item `voted` flag.
/// Mirrors the same pair on `vote` / `addComment` write paths.
Future<Map<String, String>> _asUserQuery() async {
  final externalId = await getLastExternalUserId();
  if (externalId != null) {
    return {'as_external_user_id': externalId};
  }
  return {'as_anonymous_token': await getAnonymousToken()};
}

String _escapeRequestId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) {
    throw const FeddyError(
      code: FeddyErrorCode.invalidPayload,
      message: 'Request id must not be empty',
    );
  }
  return Uri.encodeComponent(trimmed);
}

Future<RequestList> fetchRequests(
  FeddyClient client, {
  String? boardKey,
  RoadmapStatus? status,
  int? limit,
  String? cursor,
}) async {
  final clamped = limit == null ? 20 : limit.clamp(1, 100);
  final response = await client.get(
    '/v1/requests',
    query: {
      ...(await _asUserQuery()),
      if (boardKey != null) 'board_key': boardKey,
      if (status != null) 'status': status.wireValue,
      'limit': '$clamped',
      if (cursor != null) 'cursor': cursor,
    },
  );
  return RequestList.fromJson(response ?? const {});
}

Future<FeedbackRequest> fetchRequest(FeddyClient client, String id) async {
  final escaped = _escapeRequestId(id);
  final response = await client.get(
    '/v1/requests/$escaped',
    query: await _asUserQuery(),
  );
  return FeedbackRequest.fromJson(response ?? const {});
}

Future<CommentList> fetchComments(
  FeddyClient client, {
  required String requestId,
  int? limit,
  String? cursor,
}) async {
  final escaped = _escapeRequestId(requestId);
  final clamped = limit == null ? 20 : limit.clamp(1, 100);
  final response = await client.get(
    '/v1/requests/$escaped/comments',
    query: {
      'limit': '$clamped',
      if (cursor != null) 'cursor': cursor,
    },
  );
  return CommentList.fromJson(response ?? const {});
}

Future<VoteState> upvote(
  FeddyClient client, {
  required String requestId,
}) async {
  final escaped = _escapeRequestId(requestId);
  final externalUserId = await getLastExternalUserId();
  final anonymousToken =
      externalUserId == null ? await getAnonymousToken() : null;
  final response = await client.post('/v1/requests/$escaped/vote', {
    if (externalUserId != null) 'external_user_id': externalUserId,
    if (anonymousToken != null) 'anonymous_token': anonymousToken,
  });
  return VoteState.fromJson(response ?? const {});
}

Future<FeedbackComment> addComment(
  FeddyClient client, {
  required String requestId,
  required String body,
}) async {
  final escaped = _escapeRequestId(requestId);
  final trimmedBody = body.trim();
  if (trimmedBody.isEmpty) {
    throw const FeddyError(
      code: FeddyErrorCode.invalidPayload,
      message: 'Comment body must not be empty',
    );
  }
  final externalUserId = await getLastExternalUserId();
  final anonymousToken =
      externalUserId == null ? await getAnonymousToken() : null;
  final response = await client.post('/v1/requests/$escaped/comments', {
    if (externalUserId != null) 'external_user_id': externalUserId,
    if (anonymousToken != null) 'anonymous_token': anonymousToken,
    'content': trimmedBody,
  });
  return FeedbackComment.fromJson(response ?? const {});
}
