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
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _handleVote(FeedbackRequest item) async {
    final client = getCurrentClient();
    if (client == null) return;
    try {
      final state = await read_api.upvote(client, requestId: item.id);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (r) => r.id == item.id
                  ? FeedbackRequest(
                      id: r.id,
                      title: r.title,
                      description: r.description,
                      requestType: r.requestType,
                      status: r.status,
                      priority: r.priority,
                      boardId: r.boardId,
                      boardKey: r.boardKey,
                      officialReply: r.officialReply,
                      voteCount: state.voteCount,
                      voted: state.voted,
                      createdAt: r.createdAt,
                      attachments: r.attachments,
                    )
                  : r,
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
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
          return ListTile(
            title: Text(item.title),
            subtitle: Text(_boardLabel(item.boardKey)),
            trailing: TextButton.icon(
              onPressed: () => _handleVote(item),
              icon: Icon(
                item.voted ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 16,
              ),
              label: Text('${item.voteCount}'),
            ),
            onTap: () => _openDetail(item.id),
          );
        },
      ),
    );
  }
}
