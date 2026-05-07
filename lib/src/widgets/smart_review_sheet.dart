import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

/// Internal — used by `FeddyProvider` to render the Smart Review
/// pre-prompt as a Material bottom sheet. Hosts that want to render
/// it themselves can call `showModalBottomSheet` with this widget
/// directly.
class SmartReviewSheet extends StatelessWidget {
  final void Function(int stars) onRated;
  final VoidCallback onCancel;

  const SmartReviewSheet({
    super.key,
    required this.onRated,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              t('smartReview.title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              t('smartReview.subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 36,
                    tooltip: t('smartReview.star.a11y', {'n': i}),
                    icon: const Icon(Icons.star_outline),
                    color: Colors.amber.shade700,
                    onPressed: () => onRated(i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onCancel,
              child: Text(t('action.notNow')),
            ),
          ],
        ),
      ),
    );
  }
}
