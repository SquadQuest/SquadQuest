import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/chat.dart';

class EventHostBulletin extends ConsumerWidget {
  final InstanceID eventId;
  final VoidCallback onTap;

  const EventHostBulletin({
    super.key,
    required this.eventId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedMessageAsync = ref.watch(latestPinnedMessageProvider(eventId));

    return pinnedMessageAsync.when(
      loading: () => const SliverToBoxAdapter(),
      error: (_, __) => const SliverToBoxAdapter(),
      data: (message) => message == null
          ? const SliverToBoxAdapter()
          : SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Latest Update from Host',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message.content,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatRelativeTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
