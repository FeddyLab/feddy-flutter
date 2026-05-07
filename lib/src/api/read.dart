import '../client.dart';
import '../identity.dart';
import '../types.dart';

Future<RequestList> fetchRequests(
  FeddyClient client, {
  String? boardKey,
  RoadmapStatus? status,
  int? limit,
  String? cursor,
}) async {
  final response = await client.get(
    '/v1/requests',
    query: {
      if (boardKey != null) 'board_key': boardKey,
      if (status != null) 'status': status.wireValue,
      if (limit != null) 'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    },
  );
  return RequestList.fromJson(response ?? const {});
}

Future<FeedbackRequest> fetchRequest(FeddyClient client, String id) async {
  final response = await client.get('/v1/requests/$id');
  return FeedbackRequest.fromJson(response ?? const {});
}

Future<CommentList> fetchComments(
  FeddyClient client, {
  required String requestId,
  int? limit,
  String? cursor,
}) async {
  final response = await client.get(
    '/v1/requests/$requestId/comments',
    query: {
      if (limit != null) 'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    },
  );
  return CommentList.fromJson(response ?? const {});
}

Future<VoteState> upvote(
  FeddyClient client, {
  required String requestId,
}) async {
  final externalUserId = await getLastExternalUserId();
  final anonymousToken =
      externalUserId == null ? await getAnonymousToken() : null;
  final response = await client.post('/v1/requests/$requestId/votes', {
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
  final externalUserId = await getLastExternalUserId();
  final anonymousToken =
      externalUserId == null ? await getAnonymousToken() : null;
  final response = await client.post('/v1/requests/$requestId/comments', {
    if (externalUserId != null) 'external_user_id': externalUserId,
    if (anonymousToken != null) 'anonymous_token': anonymousToken,
    'content': body,
  });
  return FeedbackComment.fromJson(response ?? const {});
}
