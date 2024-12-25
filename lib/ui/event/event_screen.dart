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
import 'package:squadquest/ui/event/widgets/event_description.dart';

import '../core/widgets/rally_point_map.dart';
import 'widgets/event_live_map.dart';
import 'widgets/event_banner.dart';
import 'widgets/event_chat_sheet.dart';
import 'widgets/event_quick_actions.dart';
import 'widgets/event_info.dart';
import 'widgets/event_attendees.dart';
import 'widgets/event_rsvp_sheet.dart';
import 'widgets/event_canceled_banner.dart';

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
      useSafeArea: true,
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
      useSafeArea: true,
      enableDrag: false,
      builder: (BuildContext context) => EventLiveMap(
        eventId: widget.eventId,
        rallyPoint: eventAsync.value!.rallyPointLatLng,
      ),
    );
  }

  void _showChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => EventChatSheet(
        eventId: widget.eventId,
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
              const EventCanceledBanner(),

            // Quick Actions
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Consumer(
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
              ),
            ),

            // Event Description
            if (event.notes != null) EventDescription(description: event.notes),

            // Event Info
            EventInfo(event: event),

            // Attendees
            EventAttendees(eventId: widget.eventId),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}
