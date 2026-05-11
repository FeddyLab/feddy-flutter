import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

enum _Step { step1, step2 }

/// Internal — used by `FeddyProvider` to render the Smart Review
/// pre-prompt as a Material bottom sheet. Two-step like / dislike
/// confirmation replacing the legacy 5-star UI:
///
/// 1. "Enjoying the app?" with two buttons. A negative answer fires
///    [onDisliked] and the host pops the sheet.
/// 2. If the user picks the affirmative, the sheet transitions
///    internally to a confirmation. Tapping the affirmative there
///    fires [onStoreConfirmed] (host invokes `in_app_review`);
///    tapping "Not now" fires [onStoreDismissed].
///
/// Hosts that want to render the sheet themselves can call
/// `showModalBottomSheet` with this widget directly.
class SmartReviewSheet extends StatefulWidget {
  final VoidCallback onLiked;
  final VoidCallback onDisliked;
  final VoidCallback onStoreConfirmed;
  final VoidCallback onStoreDismissed;

  const SmartReviewSheet({
    super.key,
    required this.onLiked,
    required this.onDisliked,
    required this.onStoreConfirmed,
    required this.onStoreDismissed,
  });

  @override
  State<SmartReviewSheet> createState() => _SmartReviewSheetState();
}

class _SmartReviewSheetState extends State<SmartReviewSheet> {
  _Step _step = _Step.step1;

  void _handleLike() {
    // Non-terminal — record engagement, transition to step 2.
    widget.onLiked();
    setState(() {
      _step = _Step.step2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabHandle(),
            if (_step == _Step.step1) ..._step1Content() else ..._step2Content(),
          ],
        ),
      ),
    );
  }

  Widget _grabHandle() => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.grey.shade400,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  List<Widget> _step1Content() => [
    Text(
      t('smartReview.step1.title'),
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 6),
    Text(
      t('smartReview.step1.subtitle'),
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.grey.shade600),
    ),
    const SizedBox(height: 20),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onDisliked,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t('smartReview.step1.dislike')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _handleLike,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t('smartReview.step1.like')),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _step2Content() => [
    Text(
      t('smartReview.step2.title'),
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 6),
    Text(
      t('smartReview.step2.subtitle'),
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.grey.shade600),
    ),
    const SizedBox(height: 20),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onStoreDismissed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t('smartReview.step2.dismiss')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: widget.onStoreConfirmed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t('smartReview.step2.confirm')),
          ),
        ),
      ],
    ),
  ];
}
