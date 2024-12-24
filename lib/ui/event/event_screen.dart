import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/screens/chat.dart';

import '../core/widgets/rally_point_map.dart';
import 'widgets/event_live_map.dart';
import 'widgets/event_banner.dart';
import 'widgets/event_quick_actions.dart';
import 'widgets/event_info.dart';
import 'widgets/event_attendees.dart';
import 'widgets/event_rsvp_sheet.dart';
import 'widgets/event_invite_sheet.dart';

class EventScreen extends ConsumerStatefulWidget {
  final InstanceID eventId;

  const EventScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  String _note = '';

  InstanceMemberStatus? _getCurrentRsvpStatus(String userId) {
    final eventRsvpsAsync = ref.watch(rsvpsPerEventProvider(widget.eventId));
    if (!eventRsvpsAsync.hasValue) return null;

    return eventRsvpsAsync.value!
        .cast<InstanceMember?>()
        .firstWhereOrNull((rsvp) => rsvp?.memberId == userId)
        ?.status;
  }

  void _showRallyPointMap() async {
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));

    if (eventAsync.value == null) {
      return;
    }

    final updatedRallyPoint = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (BuildContext context) => RallyPointMap(
        initialRallyPoint: eventAsync.value!.rallyPoint,
      ),
    );

    await ref.read(instancesProvider.notifier).patch(widget.eventId, {
      'rally_point': updatedRallyPoint == null
          ? null
          : 'POINT(${updatedRallyPoint.lon} ${updatedRallyPoint.lat})',
    });

    ref.invalidate(eventDetailsProvider(widget.eventId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Rally point ${updatedRallyPoint == null ? 'cleared' : 'updated'}!'),
      ));
    }
  }

  void _showLiveMap() async {
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));

    if (eventAsync.value == null) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (BuildContext context) => EventLiveMap(
        eventId: widget.eventId,
        rallyPoint: eventAsync.value!.rallyPointLatLng,
      ),
    );
  }

  void _showChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChatScreen(
          instanceId: widget.eventId,
          autofocus: true,
        ),
      ),
    );
  }

  void _copyEventLink() async {
    await Clipboard.setData(
      ClipboardData(text: "https://squadquest.app/events/${widget.eventId}"),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event link copied to clipboard')),
      );
    }
  }

  Future<void> _saveRsvp(
      InstanceMemberStatus? status, Instance instance) async {
    try {
      final rsvpsController = ref.read(rsvpsProvider.notifier);
      final savedRsvp = await rsvpsController.save(instance, status);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            savedRsvp == null
                ? 'You\'ve removed your RSVP'
                : 'You\'ve RSVPed ${savedRsvp.status.name}',
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save RSVP: $e'),
        ));
      }
      rethrow;
    }
  }

  void _showRsvpSheet(Instance event) async {
    final session = ref.read(authControllerProvider);
    if (session == null) return;

    final eventRsvps =
        await ref.read(rsvpsPerEventProvider(widget.eventId).future);
    final myRsvp = eventRsvps
        .cast<InstanceMember?>()
        .firstWhereOrNull((rsvp) => rsvp?.memberId == session.user.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EventRsvpSheet(
        selectedStatus: myRsvp?.status,
        note: _note,
        onStatusSelected: (status, note) {
          _saveRsvp(status, event);
        },
        onRemoveRsvp: () {
          _saveRsvp(null, event);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));

    return AppScaffold(
      title: eventAsync.when(
        data: (event) => event.title,
        loading: () => '',
        error: (_, __) => 'Error loading event details',
      ),
      titleStyle: eventAsync.valueOrNull?.status == InstanceStatus.canceled
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (event) => CustomScrollView(
          slivers: [
            // Banner with event details overlay
            EventBanner(
              title: event.title,
              startTimeMin: event.startTimeMin,
              startTimeMax: event.startTimeMax,
              location: event.locationDescription,
              imageUrl: event.bannerPhoto?.toString() ??
                  'https://picsum.photos/800/400',
              isCancelled: event.status == InstanceStatus.canceled,
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
                        Consumer(
                          builder: (context, ref, child) {
                            final session = ref.watch(authControllerProvider);
                            final selectedStatus = session == null
                                ? null
                                : _getCurrentRsvpStatus(session.user.id);

                            return EventQuickActions(
                              selectedStatus: selectedStatus,
                              onRsvpTap: () => _showRsvpSheet(event),
                              onMapTap: _showLiveMap,
                              onShareTap: _copyEventLink,
                              onChatTap: _showChat,
                              showChat: selectedStatus != null,
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Event Info
                        EventInfo(
                          description: event.notes,
                          host: event.createdBy!,
                          startTimeMin: event.startTimeMin,
                          startTimeMax: event.startTimeMax,
                          endTime: event.endTime,
                          visibility: event.visibility,
                          topic: event.topic,
                        ),
                        const SizedBox(height: 24),

                        // Attendees Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Attendees',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final eventRsvps = ref
                                        .read(rsvpsPerEventProvider(
                                            widget.eventId))
                                        .value ??
                                    [];
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) => EventInviteSheet(
                                    eventId: widget.eventId,
                                    excludeUsers: eventRsvps
                                        .map((rsvp) => rsvp.memberId)
                                        .whereType<UserID>()
                                        .toList(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Invite Friends'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Attendee Sections
            EventAttendees(eventId: widget.eventId),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}
