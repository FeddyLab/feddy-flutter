import 'package:flutter/material.dart';

import '../api/boards.dart';
import '../api/read.dart' as read_api;
import '../feddy_error.dart';
import '../i18n/i18n.dart';
import '../runtime.dart';
import '../system_boards.dart';
import '../types.dart';
import 'feedback_compose_view.dart';
import 'powered_by_badge.dart';
import 'request_detail_view.dart';

class RequestListView extends StatefulWidget {
  /// Override the boards exposed in the filter menu. When null the
  /// SDK fetches the workspace's full board list automatically.
  final List<FeedbackBoard>? boards;

  const RequestListView({super.key, this.boards});

  @override
  State<RequestListView> createState() => _RequestListViewState();
}

class _RequestListViewState extends State<RequestListView> {
  late List<FeedbackBoard> _resolvedBoards;
  String? _selectedBoardKey;
  List<FeedbackRequest> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  // Per-row optimistic state. votedIds + voteOverlays mirror iOS's
  // pendingVoteIds / voteOverlays so a tap shows immediately and any
  // network failure rolls back to the baseline.
  Set<String> _votedIds = <String>{};
  final Map<String, int> _voteOverlays = <String, int>{};
  final Set<String> _pendingVoteIds = <String>{};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _resolvedBoards = widget.boards ?? systemDefaultBoards();
    _loadInitial();
    if (widget.boards == null) _refreshBoards();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _nextCursor != null &&
        !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _refreshBoards() async {
    final client = getCurrentClient();
    if (client == null) return;
    final fresh = await fetchBoards(client);
    if (!mounted || fresh.isEmpty) return;
    setState(() => _resolvedBoards = fresh);
  }

  Future<void> _loadInitial() async {
    final client = getCurrentClient();
    if (client == null) {
      setState(() {
        _error = t('compose.error.notConfigured');
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await read_api.fetchRequests(
        client,
        boardKey: _selectedBoardKey,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _votedIds = {for (final r in page.items) if (r.voted) r.id};
        _voteOverlays.clear();
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

  Future<void> _loadMore() async {
    final client = getCurrentClient();
    final cursor = _nextCursor;
    if (client == null || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await read_api.fetchRequests(
        client,
        boardKey: _selectedBoardKey,
        limit: 20,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        for (final r in page.items) {
          if (r.voted) _votedIds.add(r.id);
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _handleVote(FeedbackRequest item) async {
    if (_pendingVoteIds.contains(item.id)) return;
    final client = getCurrentClient();
    if (client == null) return;
    final wasVoted = _votedIds.contains(item.id);
    final baseline = _voteOverlays[item.id] ?? item.voteCount;
    setState(() {
      if (wasVoted) {
        _votedIds.remove(item.id);
        _voteOverlays[item.id] = (baseline - 1).clamp(0, 1 << 30);
      } else {
        _votedIds.add(item.id);
        _voteOverlays[item.id] = baseline + 1;
      }
      _pendingVoteIds.add(item.id);
    });
    try {
      final state = await read_api.upvote(client, requestId: item.id);
      if (!mounted) return;
      setState(() {
        _voteOverlays[item.id] = state.voteCount;
        if (state.voted) {
          _votedIds.add(item.id);
        } else {
          _votedIds.remove(item.id);
        }
        _pendingVoteIds.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasVoted) {
          _votedIds.add(item.id);
        } else {
          _votedIds.remove(item.id);
        }
        _voteOverlays[item.id] = baseline;
        _pendingVoteIds.remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('detail.vote.failed'))),
      );
    }
  }

  Future<void> _openCompose() async {
    final ctx = context;
    await Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedbackComposeView(
          boards: _resolvedBoards,
          boardKey: _selectedBoardKey,
        ),
        fullscreenDialog: true,
      ),
    );
    if (mounted) await _loadInitial();
  }

  Future<void> _openDetail(String id) async {
    final ctx = context;
    await Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailView(requestId: id),
      ),
    );
    if (mounted) await _loadInitial();
  }

  String _boardLabel(String key) => localizedBoardName(
        key,
        _resolvedBoards
            .firstWhere(
              (b) => b.key == key,
              orElse: () => FeedbackBoard(key: key, name: ''),
            )
            .name,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('list.title')),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: t('list.filter.all'),
            onSelected: (value) {
              setState(() => _selectedBoardKey = value);
              _loadInitial();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                value: null,
                child: Text(t('list.filter.allBoards')),
              ),
              for (final b in _resolvedBoards)
                PopupMenuItem<String?>(
                  value: b.key,
                  child: Text(localizedBoardName(b.key, b.name)),
                ),
            ],
          ),
          IconButton(
            tooltip: t('compose.title'),
            icon: const Icon(Icons.edit_note),
            onPressed: _openCompose,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            const PoweredByBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadInitial,
                child: Text(t('action.retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('list.empty.title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                t('list.empty.body'),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final item = _items[index];
          final overlay = _voteOverlays[item.id];
          final voted = _votedIds.contains(item.id);
          final pending = _pendingVoteIds.contains(item.id);
          return InkWell(
            onTap: () => _openDetail(item.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _UpvotePill(
                    count: overlay ?? item.voteCount,
                    voted: voted,
                    pending: pending,
                    onTap: () => _handleVote(item),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MiniChip(
                              label: _boardLabel(item.boardKey),
                              color: Colors.grey.shade600,
                              fillAlpha: 0.12,
                            ),
                            _StatusChip(status: item.status),
                            if (item.attachments.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    size: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${item.attachments.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          width: 46,
          height: 50,
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
              Icon(Icons.keyboard_arrow_up, size: 16, color: fg),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
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

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final double fillAlpha;

  const _MiniChip({
    required this.label,
    required this.color,
    required this.fillAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
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
