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
          extendBody: true,
          body: IndexedStack(
            index: _currentTab,
            children: _screens,
          ),
          bottomNavigationBar: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (index) {
                setState(() => _currentTab = index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.interests_outlined),
                  activeIcon: Icon(Icons.interests),
                  label: 'Interests',
                ),
              ],
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
