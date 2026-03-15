import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'community_timeline.dart';
import 'topics.dart';
import 'welcome.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentTab = 0;
  bool _showWelcome = true;

  final _screens = const [
    // Index 0: Home (community timeline)
    _KeepAlive(child: CommunityTimelineScreen()),
    // Index 1: Interests (topics)
    _KeepAlive(child: TopicsListScreenV7()),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app with bottom tabs
        Scaffold(
          body: IndexedStack(
            index: _currentTab,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: const NavigationBarThemeData(height: 56),
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: NavigationBar(
                selectedIndex: _currentTab,
                onDestinationSelected: (index) {
                  setState(() => _currentTab = index);
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.interests_outlined),
                    selectedIcon: Icon(Icons.interests),
                    label: 'Interests',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Welcome wizard overlay
        if (_showWelcome)
          WelcomeWizard(
            onDismiss: () {
              setState(() => _showWelcome = false);
            },
          ),
      ],
    );
  }
}

/// Wrapper to keep tab screens alive when switching between them
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
