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

class RoadmapView extends StatefulWidget {
  final List<FeedbackBoard>? boards;
  const RoadmapView({super.key, this.boards});

  @override
  State<RoadmapView> createState() => _RoadmapViewState();
}

class _RoadmapViewState extends State<RoadmapView>
    with SingleTickerProviderStateMixin {
  static const List<RoadmapStatus> _tabs = [
    RoadmapStatus.planned,
    RoadmapStatus.inProgress,
    RoadmapStatus.completed,
  ];

  late TabController _tabController;
  late List<FeedbackBoard> _resolvedBoards;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _resolvedBoards = widget.boards ?? systemDefaultBoards();
    if (widget.boards == null) _refreshBoards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshBoards() async {
    final client = getCurrentClient();
    if (client == null) return;
    final fresh = await fetchBoards(client);
    if (!mounted || fresh.isEmpty) return;
    setState(() => _resolvedBoards = fresh);
  }

  Future<void> _openCompose() async {
    final ctx = context;
    await Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedbackComposeView(boards: _resolvedBoards),
        fullscreenDialog: true,
      ),
    );
  }

  String _statusLabel(RoadmapStatus status) => t('status.${status.wireValue}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('roadmap.title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((s) => Tab(text: _statusLabel(s))).toList(),
        ),
        actions: [
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs
                    .map(
                      (status) => _RoadmapTab(
                        status: status,
                        boards: _resolvedBoards,
                      ),
                    )
                    .toList(),
              ),
            ),
            const PoweredByBadge(),
          ],
        ),
      ),
    );
  }
}

class _RoadmapTab extends StatefulWidget {
  final RoadmapStatus status;
  final List<FeedbackBoard> boards;

  const _RoadmapTab({required this.status, required this.boards});

  @override
  State<_RoadmapTab> createState() => _RoadmapTabState();
}

class _RoadmapTabState extends State<_RoadmapTab>
    with AutomaticKeepAliveClientMixin {
  List<FeedbackRequest> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          _nextCursor != null &&
          !_loadingMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        status: widget.status,
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
        status: widget.status,
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

  String _boardLabel(String key) => localizedBoardName(
        key,
        widget.boards
            .firstWhere(
              (b) => b.key == key,
              orElse: () => FeedbackBoard(key: key, name: ''),
            )
            .name,
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          child: Text(
            t(
              'roadmap.empty.titleFormat',
              {'status': t('status.${widget.status.wireValue}')},
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
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
            trailing: Text('${item.voteCount}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RequestDetailView(requestId: item.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
