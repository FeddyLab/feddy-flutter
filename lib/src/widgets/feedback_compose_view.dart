import 'package:flutter/material.dart';

import '../api/boards.dart';
import '../attachments/upload.dart';
import '../client.dart';
import '../feddy_error.dart';
import '../i18n/i18n.dart';
import '../identity.dart';
import '../runtime.dart';
import '../system_boards.dart';
import '../types.dart';
import 'attachment_picker_button.dart';
import 'powered_by_badge.dart';

/// Material `Scaffold` form for collecting feedback. Pop-up host:
/// either via `Feddy.openFeedback()` (rendered by `FeddyProvider`),
/// or directly via `showModalBottomSheet` / `Navigator.push` from
/// host code.
class FeedbackComposeView extends StatefulWidget {
  /// Override the boards exposed in the picker. When null the SDK
  /// fetches the workspace's full board list (`GET /v1/boards`,
  /// 1 h cached) and falls back to `systemDefaults` while loading
  /// or on failure.
  final List<FeedbackBoard>? boards;

  /// Pre-select a specific board.
  final String? boardKey;
  final VoidCallback? onDismiss;

  const FeedbackComposeView({
    super.key,
    this.boards,
    this.boardKey,
    this.onDismiss,
  });

  @override
  State<FeedbackComposeView> createState() => _FeedbackComposeViewState();
}

class _FeedbackComposeViewState extends State<FeedbackComposeView> {
  late List<FeedbackBoard> _resolvedBoards;
  String _title = '';
  String _description = '';
  String _selectedBoardKey = '';
  List<String> _imagePaths = [];
  bool _attachmentsEnabled = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolvedBoards = widget.boards ?? systemDefaultBoards();
    _selectedBoardKey = _initialBoardKey();
    _loadAttachmentsFlag();
    if (widget.boards == null) {
      _refreshBoards();
    }
  }

  String _initialBoardKey() {
    final preferred = widget.boardKey;
    if (preferred != null && _resolvedBoards.any((b) => b.key == preferred)) {
      return preferred;
    }
    return _resolvedBoards.isNotEmpty ? _resolvedBoards.first.key : '';
  }

  Future<void> _loadAttachmentsFlag() async {
    final enabled = await getAttachmentsEnabled();
    if (!mounted) return;
    setState(() => _attachmentsEnabled = enabled);
  }

  Future<void> _refreshBoards() async {
    final client = getCurrentClient();
    if (client == null) return;
    final fresh = await fetchBoards(client);
    if (!mounted || fresh.isEmpty) return;
    setState(() {
      _resolvedBoards = fresh;
      if (!fresh.any((b) => b.key == _selectedBoardKey)) {
        _selectedBoardKey = fresh.first.key;
      }
    });
  }

  Future<void> _submit() async {
    final trimmedTitle = _title.trim();
    if (trimmedTitle.isEmpty) {
      setState(() => _error = t('compose.error.titleEmpty'));
      return;
    }
    final client = getCurrentClient();
    if (client == null) {
      setState(() => _error = t('compose.error.notConfigured'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final attachmentKeys = await _uploadAttachments(client);
      final externalUserId = await getLastExternalUserId();
      final anonymousToken =
          externalUserId == null ? await getAnonymousToken() : null;
      final desc = _description.trim();
      await client.post('/v1/requests', {
        if (externalUserId != null) 'external_user_id': externalUserId,
        if (anonymousToken != null) 'anonymous_token': anonymousToken,
        'title': trimmedTitle,
        if (desc.isNotEmpty) 'description': desc,
        if (_selectedBoardKey.isNotEmpty) 'board_key': _selectedBoardKey,
        if (attachmentKeys.isNotEmpty) 'attachment_keys': attachmentKeys,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('compose.thanks'))),
      );
      widget.onDismiss?.call();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FeddyError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t('compose.error.submitFailed');
        _submitting = false;
      });
    }
  }

  Future<List<String>> _uploadAttachments(FeddyClient client) async {
    final keys = <String>[];
    for (final path in _imagePaths.take(3)) {
      try {
        final key = await uploadAttachment(client, path);
        keys.add(key);
      } catch (e) {
        // ignore: avoid_print
        print('[Feddy] attachment upload failed — skipping one: $e');
      }
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('compose.title')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: t('action.cancel'),
          onPressed: _submitting
              ? null
              : () {
                  widget.onDismiss?.call();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
        ),
        actions: [
          TextButton(
            onPressed: _submitting || _title.trim().isEmpty ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('action.submit')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    autofocus: true,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: t('compose.placeholder.title'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _title = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    enabled: !_submitting,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: t('compose.placeholder.description'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (v) => setState(() => _description = v),
                  ),
                  if (_resolvedBoards.length > 1) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value:
                          _selectedBoardKey.isEmpty ? null : _selectedBoardKey,
                      decoration: InputDecoration(
                        labelText: t('list.filter.allBoards'),
                        border: const OutlineInputBorder(),
                      ),
                      items: _resolvedBoards
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.key,
                              child: Text(
                                localizedBoardName(b.key, b.name),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _selectedBoardKey = v);
                              }
                            },
                    ),
                  ],
                  if (_attachmentsEnabled) ...[
                    const SizedBox(height: 16),
                    AttachmentPickerButton(
                      paths: _imagePaths,
                      disabled: _submitting,
                      onChange: (next) => setState(() => _imagePaths = next),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
            const PoweredByBadge(),
          ],
        ),
      ),
    );
  }
}
