import 'package:flutter/material.dart';

class WelcomeWizard extends StatefulWidget {
  final VoidCallback onDismiss;

  const WelcomeWizard({super.key, required this.onDismiss});

  @override
  State<WelcomeWizard> createState() => _WelcomeWizardState();
}

class _WelcomeWizardState extends State<WelcomeWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _WelcomePage(
      icon: Icons.rocket_launch_outlined,
      iconColor: Colors.deepOrange,
      title: 'Rally the squad. Go hang.',
      body:
          "SquadQuest isn't a business. We built this tool to coordinate in-person activities with our friends using event-focused group chats.\n\nIt's free to use and privacy-first. Only mutually-confirmed friends can see your details and activity.",
    ),
    _WelcomePage(
      icon: Icons.how_to_vote_outlined,
      iconColor: Colors.purple,
      title: 'How it works',
      body:
          "Share an idea for something to do, suggest times and places, and let friends vote. When it works for everyone, lock it in and go.",
    ),
    _WelcomePage(
      icon: Icons.volunteer_activism_outlined,
      iconColor: Colors.teal,
      title: 'How is this free?',
      body:
          "SquadQuest is open source and cheap to host. We don't need ads, subscription fees, or investors, and we won't ever sell your info or market to you.\n\nThis tool is built by and for its users.",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: page.iconColor.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 40,
                            color: page.iconColor,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators + button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1 ? 'Next' : "Let's go!",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _WelcomePage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}
