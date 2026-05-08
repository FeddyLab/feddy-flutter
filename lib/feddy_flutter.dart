/// Feddy SDK for Flutter — feedback infrastructure for mobile apps.
///
/// Two calls cover the integration:
///
/// ```dart
/// // 1. Once at app launch:
/// Feddy.configure(apiKey: 'fed_xxxxxxxxxxxx');
///
/// // 2. After your auth handler runs:
/// Feddy.identify(userId: user.id, email: user.email, displayName: user.name);
/// ```
///
/// See README.md for the full surface (compose / list / detail /
/// roadmap views, smart review, attachments, custom-board i18n).
library feddy_flutter;

export 'src/feddy.dart' show Feddy;
export 'src/feddy_error.dart' show FeddyError, FeddyErrorCode;
export 'src/i18n/i18n.dart' show FeddyLocale, setLocale;
export 'src/system_boards.dart' show BoardTranslations;
export 'src/types.dart'
    show
        Attachment,
        Branding,
        CommentAuthorKind,
        CommentList,
        FeedbackBoard,
        FeedbackComment,
        FeedbackRequest,
        RequestList,
        RoadmapStatus,
        Subscription,
        SubscriptionStatus,
        VoteState;
export 'src/version.dart' show sdkVersion;
export 'src/widgets/attachment_picker_button.dart' show AttachmentPickerButton;
export 'src/widgets/feddy_provider.dart' show FeddyProvider;
export 'src/widgets/feedback_compose_view.dart' show FeedbackComposeView;
export 'src/widgets/powered_by_badge.dart' show PoweredByBadge;
export 'src/widgets/request_detail_view.dart' show RequestDetailView;
export 'src/widgets/request_list_view.dart' show RequestListView;
export 'src/widgets/roadmap_view.dart' show RoadmapView;
export 'src/widgets/smart_review_sheet.dart' show SmartReviewSheet;
