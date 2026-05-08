import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../types.dart';

/// Shared row used by `RequestListView` and the `RoadmapView` tabs.
/// Keeping the layout, the upvote pill, and the chips in one place
/// guarantees the two surfaces stay visually identical — same way iOS
/// shares `RequestRow` between its list and roadmap views.
class FeddyRequestRow extends StatelessWidget {
  final FeedbackRequest request;
  final String boardName;
  final int? voteOverlay;
  final bool voted;
  final bool votePending;
  final bool showStatusChip;
  final VoidCallback onVoteTap;
  final VoidCallback onTap;

  const FeddyRequestRow({
    super.key,
    required this.request,
    required this.boardName,
    required this.voteOverlay,
    required this.voted,
    required this.votePending,
    required this.showStatusChip,
    required this.onVoteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = voteOverlay ?? request.voteCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FeddyUpvotePill(
                    count: count,
                    voted: voted,
                    pending: votePending,
                    onTap: onVoteTap,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (request.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            request.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FeddyMiniChip(
                              label: boardName,
                              color: Colors.grey.shade700,
                              fillAlpha: 0.10,
                            ),
                            if (showStatusChip)
                              FeddyStatusChip(status: request.status),
                            if (request.attachments.isNotEmpty)
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
                                    '${request.attachments.length}',
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
          ),
        ),
      ),
    );
  }
}

class FeddyUpvotePill extends StatelessWidget {
  final int count;
  final bool voted;
  final bool pending;
  final VoidCallback onTap;

  const FeddyUpvotePill({
    super.key,
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

class FeddyMiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final double fillAlpha;

  const FeddyMiniChip({
    super.key,
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

class FeddyStatusChip extends StatelessWidget {
  final String status;

  const FeddyStatusChip({super.key, required this.status});

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
