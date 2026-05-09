import 'package:feddy_flutter/feddy_flutter.dart';
import 'package:flutter/material.dart';

const String _kApiKey = String.fromEnvironment('FEDDY_API_KEY');

/// Stand-in for the user record the host app already has after its
/// own authentication flow. Feddy never authenticates end users — the
/// host app passes whatever identifier and traits it already knows.
///
/// Each platform demo uses a **distinct** user identity so a tester
/// running both apps side-by-side can see the comment-bubble visual
/// distinction in action: every comment shows up as `is_self=true` on
/// the platform that posted it (orange right-aligned "You"), and as
/// the other platform's display name on the other one (neutral
/// left-aligned). iOS uses Alice Chen, RN uses Charlie Tan.
class _DemoUser {
  static const String id = 'demo_user_bob';
  static const String email = 'bob@example.com';
  static const String displayName = 'Bob Park';
}

void main() {
  if (_kApiKey.isNotEmpty) {
    // Canonical: configure once at launch, before any view runs.
    Feddy.configure(apiKey: _kApiKey);
    // In your real app, call this from your auth handler with the
    // user record you already have. The demo simulates with
    // hardcoded values matching the iOS sample app.
    Feddy.identify(
      userId: _DemoUser.id,
      email: _DemoUser.email,
      displayName: _DemoUser.displayName,
    );
  }
  runApp(const _DemoApp());
}

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feddy Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const FeddyProvider(child: _DemoHome()),
    );
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome();

  @override
  Widget build(BuildContext context) {
    if (_kApiKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Feddy Flutter Demo')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Set FEDDY_API_KEY at run-time:\n\n'
              '  flutter run --dart-define=FEDDY_API_KEY=fed_xxxxxxxxxxxx',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Feddy Flutter Demo')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _Section(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Re-identify demo user'),
                subtitle: const Text(
                  '${_DemoUser.id} — ${_DemoUser.email}\n'
                  '(auto-fires once at launch; tap to refresh profile)',
                ),
                isThreeLine: true,
                onTap: () {
                  Feddy.identify(
                    userId: _DemoUser.id,
                    email: _DemoUser.email,
                    displayName: _DemoUser.displayName,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('identify dispatched')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: const Text('Set Pro subscription (manual override)'),
                onTap: () {
                  Feddy.setSubscription(
                    const Subscription(
                      isPaid: true,
                      status: SubscriptionStatus.active,
                      productId: 'demo_pro_yearly',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pro subscription set')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Reset (forget user)'),
                onTap: () {
                  Feddy.reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feddy state reset')),
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'Share Feedback',
            children: [
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Open compose modal'),
                onTap: () => Feddy.openFeedback(),
              ),
            ],
          ),
          _Section(
            title: 'Browse',
            children: [
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('Request List'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RequestListView(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text('Roadmap'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapView(),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Smart Review (debug)',
            children: [
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Trigger via gates (likely skipped)'),
                onTap: () => Feddy.requestReviewIfAppropriate(
                  trigger: 'demo.button',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Bypass gates (always show)'),
                onTap: () => Feddy.requestReviewIfAppropriate(
                  trigger: 'demo.bypass',
                  bypassGates: true,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Smart Review counters'),
                onTap: () {
                  Feddy.resetSmartReviewState();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Smart Review state cleared'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
