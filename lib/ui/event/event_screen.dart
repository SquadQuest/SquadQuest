import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

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
  late ScrollController scrollController;
  bool isBannerCollapsed = false;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController()
      ..addListener(() {
        if (scrollController.offset >
                eventBannerExpandedHeight - kToolbarHeight &&
            !isBannerCollapsed) {
          setState(() => isBannerCollapsed = true);
        } else if (scrollController.offset <=
                eventBannerExpandedHeight - kToolbarHeight &&
            isBannerCollapsed) {
          setState(() => isBannerCollapsed = false);
        }
      });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  InstanceMemberStatus? _getCurrentRsvpStatus(UserID userId) {
    final eventRsvpsAsync = ref.watch(rsvpsPerEventProvider(widget.eventId));
    if (!eventRsvpsAsync.hasValue) return null;

    return eventRsvpsAsync.value!
        .cast<InstanceMember?>()
        .firstWhereOrNull((rsvp) => rsvp?.memberId == userId)
        ?.status;
  }

  void _handleHostAction(EventHostAction action) {
    switch (action) {
      case EventHostAction.setRallyPoint:
        _showRallyPointMap();
        break;
      case EventHostAction.edit:
        context.pushNamed(
          'event-edit',
          pathParameters: {'id': widget.eventId},
        );
        break;
      case EventHostAction.cancel:
      case EventHostAction.uncancel:
        _cancelEvent(action == EventHostAction.cancel);
        break;
      case EventHostAction.duplicate:
        context.pushNamed(
          'post-event',
          queryParameters: {'duplicateEventId': widget.eventId},
        );
        break;
    }
  }

  Future<void> _cancelEvent([bool canceled = true]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('${canceled ? 'Cancel' : 'Uncancel'} event?'),
        content: Text(
          'Are you sure you want to ${canceled ? 'cancel' : 'uncancel'} this event? Guests will be alerted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(instancesProvider.notifier).patch(
      widget.eventId,
      {'status': canceled ? 'canceled' : 'live'},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Your event has been ${canceled ? 'canceled' : 'uncanceled'} and guests will be alerted',
        ),
      ));
    }
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
        event: event,
        selectedStatus: myRsvp?.status,
        // note: _note,
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
    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));

    return AppScaffold(
      showAppBar: false,
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (event) => CustomScrollView(
          controller: scrollController,
          slivers: [
            // Banner with event details overlay
            EventBanner(
              event: event,
              isCollapsed: isBannerCollapsed,
              currentUserId: session?.user.id,
              onHostAction: _handleHostAction,
            ),

            // Canceled Banner
            if (event.status == InstanceStatus.canceled)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.red.withOpacity(0.1),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Colors.red),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'This event has been cancelled',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Contact the host for more information',
                              style: TextStyle(
                                color: Colors.red.withAlpha(200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                              eventId: widget.eventId,
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
