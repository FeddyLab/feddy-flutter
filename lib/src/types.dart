// ---------- Subscription ----------

/// Locked status set understood by `feddy-api`. Server rejects any
/// other string with `invalid_payload` so out-of-band values never
/// land in the dashboard.
enum SubscriptionStatus { active, trial, expired, none }

extension SubscriptionStatusWire on SubscriptionStatus {
  String get wireValue {
    switch (this) {
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.trial:
        return 'trial';
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.none:
        return 'none';
    }
  }

  static SubscriptionStatus fromWire(String value) {
    switch (value) {
      case 'active':
        return SubscriptionStatus.active;
      case 'trial':
        return SubscriptionStatus.trial;
      case 'expired':
        return SubscriptionStatus.expired;
      default:
        return SubscriptionStatus.none;
    }
  }
}

class Subscription {
  final bool isPaid;
  final SubscriptionStatus status;
  final String? productId;

  /// ISO 8601 timestamp.
  final String? expiresAt;

  const Subscription({
    required this.isPaid,
    required this.status,
    this.productId,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'is_paid': isPaid,
        'status': status.wireValue,
        if (productId != null) 'product_id': productId,
        if (expiresAt != null) 'expires_at': expiresAt,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        isPaid: json['is_paid'] as bool? ?? false,
        status: SubscriptionStatusWire.fromWire(
          json['status'] as String? ?? 'none',
        ),
        productId: json['product_id'] as String?,
        expiresAt: json['expires_at'] as String?,
      );
}

// ---------- Boards ----------

/// A board to display in the compose view's picker. The [key] is
/// what the SDK writes to `request.board_key` on submit; the [name]
/// is what the end user sees.
class FeedbackBoard {
  final String key;
  final String name;

  const FeedbackBoard({required this.key, required this.name});

  Map<String, dynamic> toJson() => {'key': key, 'name': name};

  factory FeedbackBoard.fromJson(Map<String, dynamic> json) => FeedbackBoard(
        key: json['key'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedbackBoard && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(key, name);
}

// ---------- Branding (capabilities) ----------

class Branding {
  final bool show;
  final String text;
  final String url;
  final String? logoUrl;

  const Branding({
    required this.show,
    required this.text,
    required this.url,
    this.logoUrl,
  });

  /// Hardcoded fallback for first launch when no cache has been
  /// written yet. Favors showing the badge so a Free workspace
  /// doesn't get a silent free pass while offline.
  static const Branding fallback = Branding(
    show: true,
    text: 'Powered by Feddy',
    url: 'https://feddy.app',
  );

  factory Branding.fromJson(Map<String, dynamic> json) => Branding(
        show: json['show'] as bool? ?? true,
        text: json['text'] as String? ?? 'Powered by Feddy',
        url: json['url'] as String? ?? 'https://feddy.app',
        logoUrl: json['logo_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'show': show,
        'text': text,
        'url': url,
        if (logoUrl != null) 'logo_url': logoUrl,
      };
}

// ---------- Read-side domain ----------

/// The three publicly-visible roadmap statuses. Backend rejects any
/// other value as `invalid_query` so internal triage state never leaks.
enum RoadmapStatus { planned, inProgress, completed }

extension RoadmapStatusWire on RoadmapStatus {
  String get wireValue {
    switch (this) {
      case RoadmapStatus.planned:
        return 'planned';
      case RoadmapStatus.inProgress:
        return 'in_progress';
      case RoadmapStatus.completed:
        return 'completed';
    }
  }
}

class Attachment {
  final String key;
  final String assetUrl;
  final String contentType;
  final int size;

  const Attachment({
    required this.key,
    required this.assetUrl,
    required this.contentType,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        key: json['key'] as String,
        assetUrl: json['asset_url'] as String,
        contentType: json['content_type'] as String,
        size: json['size'] as int? ?? 0,
      );
}

class FeedbackRequest {
  final String id;
  final String title;
  final String description;
  final String requestType;
  final String status;
  final String priority;
  final String boardId;
  final String boardKey;
  final String? officialReply;
  final int voteCount;
  final bool voted;

  /// ISO 8601 timestamp.
  final String createdAt;
  final List<Attachment> attachments;

  const FeedbackRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.requestType,
    required this.status,
    required this.priority,
    required this.boardId,
    required this.boardKey,
    required this.officialReply,
    required this.voteCount,
    required this.voted,
    required this.createdAt,
    required this.attachments,
  });

  factory FeedbackRequest.fromJson(Map<String, dynamic> json) {
    final attachments = (json['attachments'] as List?)
            ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return FeedbackRequest(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requestType: json['request_type'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'normal',
      boardId: json['board_id'] as String? ?? '',
      boardKey: json['board_key'] as String? ?? '',
      officialReply: json['official_reply'] as String?,
      voteCount: json['vote_count'] as int? ?? 0,
      voted: json['voted'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      attachments: attachments,
    );
  }
}

class RequestList {
  final List<FeedbackRequest> items;

  /// Pass back as `cursor` to load the next page; `null` = no more.
  final String? nextCursor;

  const RequestList({required this.items, required this.nextCursor});

  factory RequestList.fromJson(Map<String, dynamic> json) => RequestList(
        items: (json['items'] as List?)
                ?.map(
                  (e) => FeedbackRequest.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        nextCursor: json['next_cursor'] as String?,
      );
}

class FeedbackComment {
  final String id;
  final String content;
  final String? authorEndUserId;

  /// ISO 8601 timestamp.
  final String createdAt;

  /// ISO 8601 timestamp.
  final String updatedAt;

  const FeedbackComment({
    required this.id,
    required this.content,
    required this.authorEndUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeedbackComment.fromJson(Map<String, dynamic> json) =>
      FeedbackComment(
        id: json['id'] as String,
        content: json['content'] as String? ?? '',
        authorEndUserId: json['author_end_user_id'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );
}

class CommentList {
  final List<FeedbackComment> items;
  final String? nextCursor;

  const CommentList({required this.items, required this.nextCursor});

  factory CommentList.fromJson(Map<String, dynamic> json) => CommentList(
        items: (json['items'] as List?)
                ?.map(
                  (e) => FeedbackComment.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        nextCursor: json['next_cursor'] as String?,
      );
}

class VoteState {
  final bool voted;
  final int voteCount;

  const VoteState({required this.voted, required this.voteCount});

  factory VoteState.fromJson(Map<String, dynamic> json) => VoteState(
        voted: json['voted'] as bool? ?? false,
        voteCount: json['vote_count'] as int? ?? 0,
      );
}
