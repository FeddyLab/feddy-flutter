import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../capabilities.dart';
import '../runtime.dart';
import '../types.dart';

/// Server-driven footer rendered at the bottom of bundled views.
/// Reads the cached branding from `currentBranding()`; a fresh
/// background refresh is kicked from each render so the badge
/// converges within 24 h of any plan change.
///
/// Hosts that render their own custom feedback views can mount this
/// at the bottom of their own scaffold to stay in compliance.
class PoweredByBadge extends StatefulWidget {
  const PoweredByBadge({super.key});

  @override
  State<PoweredByBadge> createState() => _PoweredByBadgeState();
}

class _PoweredByBadgeState extends State<PoweredByBadge> {
  Branding? _branding;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branding = await currentBranding();
    if (!mounted) return;
    setState(() {
      _branding = branding;
      _resolved = true;
    });
    final client = getCurrentClient();
    if (client != null) {
      refreshCapabilitiesInBackground(client);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) return const SizedBox.shrink();
    final branding = _branding;
    if (branding == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final uri = Uri.parse(branding.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (branding.logoUrl != null) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: Image.network(
                  branding.logoUrl!,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              branding.text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
