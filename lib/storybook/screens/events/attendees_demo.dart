import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/storybook/components/modals/attendees_modal.dart';

class AttendeesDemoScreen extends ConsumerWidget {
  const AttendeesDemoScreen({super.key});

  void _showAttendeesModal(BuildContext context,
      {required bool showFriendButtons}) {
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AttendeesModal(showFriendButtons: showFriendButtons),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showFriendButtons = context.knobs.boolean(
      label: 'Show friend buttons',
      initial: false,
      description: 'Toggle friend request buttons in attendee list',
    );

    return AppScaffold(
      title: 'Event Details',
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Who\'s Coming',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      'https://i.pravatar.cc/300?u=sarah',
                                    ),
                                  ),
                                  Positioned(
                                    left: 24,
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        'https://i.pravatar.cc/300?u=mike',
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 48,
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        'https://i.pravatar.cc/300?u=emma',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 64),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '24 people coming',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      '18 going • 6 maybe',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showAttendeesModal(
                                  context,
                                  showFriendButtons: showFriendButtons,
                                ),
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
