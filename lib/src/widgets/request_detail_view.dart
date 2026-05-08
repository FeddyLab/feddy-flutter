import 'package:flutter/material.dart';

import '../api/read.dart' as read_api;
import '../feddy_error.dart';
import '../i18n/i18n.dart';
import '../runtime.dart';
import '../types.dart';
import 'powered_by_badge.dart';

class RequestDetailView extends StatefulWidget {
  final String requestId;
  final VoidCallback? onBack;

  const RequestDetailView({
    super.key,
    required this.requestId,
    this.onBack,
  });

  @override
  State<RequestDetailView> createState() => _RequestDetailViewState();
}

class _RequestDetailViewState extends State<RequestDetailView> {
  FeedbackRequest? _request;
  List<FeedbackComment> _comments = [];
  String? _commentsCursor;
  bool _loading = true;
  bool _loadingMoreComments = false;
  bool _votePending = false;
  bool _voted = false;
  int? _voteCountOverride;
  bool _sendingComment = false;
  String? _error;
  String _newComment = '';
  Attachment? _lightboxAttachment;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final client = getCurrentClient();
    if (client == null) {
      setState(() {
        _error = t('compose.error.notConfigured');
        _loading = false;
      });
      return;
    }
    try {
      // Fire detail + first comments page in parallel — same pattern as
      // iOS RequestDetailView's `async let` pair so users see content
      // as fast as the slower of the two endpoints.
      final results = await Future.wait([
        read_api.fetchRequest(client, widget.requestId),
        read_api.fetchComments(client, requestId: widget.requestId, limit: 20),
      ]);
      if (!mounted) return;
      final request = results[0] as FeedbackRequest;
      final commentsPage = results[1] as CommentList;
      setState(() {
        _request = request;
        _voted = request.voted;
        _voteCountOverride = null;
        _comments = commentsPage.items;
        _commentsCursor = commentsPage.nextCursor;
        _loading = false;
      });
    } on FeddyError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = t('list.error');
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    final client = getCurrentClient();
    final cursor = _commentsCursor;
    if (client == null || cursor == null || _loadingMoreComments) return;
    setState(() => _loadingMoreComments = true);
    try {
      final page = await read_api.fetchComments(
        client,
        requestId: widget.requestId,
        limit: 20,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, ...page.items];
        _commentsCursor = page.nextCursor;
        _loadingMoreComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMoreComments = false);
    }
  }

  Future<void> _toggleVote() async {
    final request = _request;
    final client = getCurrentClient();
    if (request == null || client == null || _votePending) return;
    final wasVoted = _voted;
    final baseline = _voteCountOverride ?? request.voteCount;
    setState(() {
      _voted = !wasVoted;
      _voteCountOverride = wasVoted ? (baseline - 1).clamp(0, 1 << 30) : baseline + 1;
      _votePending = true;
    });
    try {
      final state = await read_api.upvote(client, requestId: request.id);
      if (!mounted) return;
      setState(() {
        _voted = state.voted;
        _voteCountOverride = state.voteCount;
        _votePending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voted = wasVoted;
        _voteCountOverride = baseline;
        _votePending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('detail.vote.failed'))),
      );
    }
  }

  Future<void> _submitComment() async {
    final body = _newComment.trim();
    final client = getCurrentClient();
    if (body.isEmpty || client == null || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final comment = await read_api.addComment(
        client,
        requestId: widget.requestId,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _newComment = '';
        _sendingComment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('detail.comment.failed'))),
      );
    }
  }

  void _openLightbox(Attachment attachment) {
    setState(() => _lightboxAttachment = attachment);
  }

  void _closeLightbox() {
    setState(() => _lightboxAttachment = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                widget.onBack?.call();
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
            ),
            title: Text(
              _request?.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                });
                                _loadAll();
                              },
                              child: Text(t('action.retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildBody(),
        ),
        if (_lightboxAttachment != null)
          _AttachmentLightbox(
            attachment: _lightboxAttachment!,
            onClose: _closeLightbox,
          ),
      ],
    );
  }

  Widget _buildBody() {
    final request = _request!;
    final voteCount = _voteCountOverride ?? request.voteCount;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _StatusChip(status: request.status),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(request.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _UpvotePill(
                      count: voteCount,
                      voted: _voted,
                      pending: _votePending,
                      onTap: _toggleVote,
                    ),
                  ],
                ),
                if (request.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(request.description),
                ],
                if (request.officialReply != null &&
                    request.officialReply!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    t('detail.officialReply'),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(request.officialReply!),
                  ),
                ],
                if (request.attachments.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    t('detail.attachments'),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: request.attachments
                        .map(
                          (a) => GestureDetector(
                            onTap: () => _openLightbox(a),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                a.assetUrl,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : Container(
                                            width: 88,
                                            height: 88,
                                            color: Colors.grey.shade200,
                                            alignment: Alignment.center,
                                            child:
                                                const CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                errorBuilder: (_, __, ___) => Container(
                                  width: 88,
                                  height: 88,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  t('detail.comments'),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      t('detail.comments.empty'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  ..._comments.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.content),
                            if (c.createdAt.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(c.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_commentsCursor != null)
                  Center(
                    child: TextButton(
                      onPressed:
                          _loadingMoreComments ? null : _loadMoreComments,
                      child: _loadingMoreComments
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t('detail.comments.loadMore')),
                    ),
                  ),
                const SizedBox(height: 8),
                const PoweredByBadge(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    enabled: !_sendingComment,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: t('detail.comment.placeholder'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _newComment = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sendingComment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _newComment.trim().isEmpty || _sendingComment
                      ? null
                      : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }
}

class _UpvotePill extends StatelessWidget {
  final int count;
  final bool voted;
  final bool pending;
  final VoidCallback onTap;

  const _UpvotePill({
    required this.count,
    required this.voted,
    required this.pending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = voted ? Colors.orange : Colors.grey.shade100;
    final fg = voted ? Colors.white : Colors.grey.shade800;
    return Semantics(
      button: true,
      label: voted ? t('action.upvoted') : t('action.upvote'),
      child: InkWell(
        onTap: pending ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 52,
          height: 56,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: voted
                ? null
                : Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_arrow_up, size: 18, color: fg),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'planned':
        return Colors.orange;
      case 'rejected':
      case 'duplicate':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String _statusLabel(String status) {
    final key = 'status.$status';
    final value = t(key);
    return value == key ? status : value;
  }
}

class _AttachmentLightbox extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onClose;

  const _AttachmentLightbox({
    required this.attachment,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    attachment.assetUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

