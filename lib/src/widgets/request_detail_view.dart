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
  bool _voting = false;
  bool _sendingComment = false;
  String? _error;
  String _newComment = '';

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
      final request = await read_api.fetchRequest(client, widget.requestId);
      final commentsPage = await read_api.fetchComments(
        client,
        requestId: widget.requestId,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
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
    } catch (e) {
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
    if (client == null || cursor == null) return;
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
      });
    } catch (_) {
      // Silent stop on pagination errors.
    }
  }

  Future<void> _toggleVote() async {
    final request = _request;
    final client = getCurrentClient();
    if (request == null || client == null || _voting) return;
    setState(() => _voting = true);
    try {
      final state = await read_api.upvote(client, requestId: request.id);
      if (!mounted) return;
      setState(() {
        _request = FeedbackRequest(
          id: request.id,
          title: request.title,
          description: request.description,
          requestType: request.requestType,
          status: request.status,
          priority: request.priority,
          boardId: request.boardId,
          boardKey: request.boardKey,
          officialReply: request.officialReply,
          voteCount: state.voteCount,
          voted: state.voted,
          createdAt: request.createdAt,
          attachments: request.attachments,
        );
        _voting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _voting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildBody() {
    final request = _request!;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  request.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _voting ? null : _toggleVote,
                      icon: Icon(
                        request.voted
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 16,
                      ),
                      label: Text(
                        '${request.voteCount} '
                        '${request.voted ? t('action.upvoted') : t('action.upvote')}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(label: Text(request.status)),
                  ],
                ),
                if (request.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(request.description),
                ],
                if (request.officialReply != null) ...[
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
                const SizedBox(height: 24),
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
                        child: Text(c.content),
                      ),
                    ),
                  ),
                if (_commentsCursor != null)
                  Center(
                    child: TextButton(
                      onPressed: _loadMoreComments,
                      child: Text(t('detail.comments.loadMore')),
                    ),
                  ),
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
          const PoweredByBadge(),
        ],
      ),
    );
  }
}
