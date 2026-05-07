import 'package:feddy_flutter/feddy_flutter.dart';
import 'package:flutter/material.dart';

const String _kApiKey = String.fromEnvironment('FEDDY_API_KEY');

void main() {
  if (_kApiKey.isNotEmpty) {
    Feddy.configure(apiKey: _kApiKey);
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
                title: const Text('Identify demo user'),
                subtitle: const Text('user_42 — demo@example.com'),
                onTap: () {
                  Feddy.identify(
                    userId: 'user_42',
                    email: 'demo@example.com',
                    displayName: 'Demo User',
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
