import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';

import 'widgets/event_banner.dart';
import 'widgets/event_quick_actions.dart';
import 'widgets/event_info.dart';
import 'widgets/event_attendees.dart';
import 'widgets/event_rsvp_sheet.dart';

class EventScreen extends ConsumerStatefulWidget {
  final String instanceId;

  const EventScreen({
    super.key,
    required this.instanceId,
  });

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  InstanceMemberStatus? _selectedStatus;
  String _note = '';

  void _showRsvpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EventRsvpSheet(
        selectedStatus: _selectedStatus,
        note: _note,
        onStatusSelected: (status, note) {
          setState(() {
            _selectedStatus = status;
            _note = note;
          });
        },
        onRemoveRsvp: () {
          setState(() {
            _selectedStatus = null;
            _note = '';
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Board Game Night',
      body: CustomScrollView(
        slivers: [
          // Banner with event details overlay
          const EventBanner(
            title: 'Board Game Night',
            date: 'Friday, March 15',
            startTime: '7:00-7:30 PM',
            location: 'Game Knight Lounge',
            imageUrl: 'https://picsum.photos/800/400',
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      EventQuickActions(
                        selectedStatus: _selectedStatus,
                        onRsvpTap: _showRsvpSheet,
                      ),
                      const SizedBox(height: 24),

                      // Event Info
                      const EventInfo(
                        description:
                            'Join us for a night of strategy and fun! We\'ll have a variety of games available, from quick party games to longer strategy games. Beginners welcome! Food and drinks available for purchase.',
                        host: 'Sarah Chen',
                        startTime: '7:00-7:30 PM',
                        endTime: '10:00 PM',
                        visibility: 'Friends Only',
                        topic: 'Board Games',
                      ),
                      const SizedBox(height: 24),

                      // Attendees Header
                      const Text(
                        'Attendees',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Attendee Sections
          const EventAttendees(),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}
