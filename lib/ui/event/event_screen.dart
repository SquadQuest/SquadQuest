import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:squadquest/controllers/chat.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/instances.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/location.dart';

import '../core/widgets/rally_point_map.dart';
import 'widgets/event_live_map.dart';
import 'widgets/event_banner.dart';
import 'widgets/event_chat_sheet.dart';
import 'widgets/event_quick_actions.dart';
import 'widgets/event_host_bulletin.dart';
import 'widgets/event_description.dart';
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
  ScaffoldFeatureController? rsvpSnackbar;
  late ScrollController scrollController;
  bool isBannerCollapsed = false;
  late Timer refreshIndicatorsTimer;

  @override
  void initState() {
    super.initState();

    // track scrolling to determine when banner is collapsed
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

    // start timer to refreshh indicators periodically
    refreshIndicatorsTimer =
        Timer.periodic(const Duration(seconds: 15), (Timer t) {
      ref.invalidate(eventPointsProvider(widget.eventId));
      ref.invalidate(chatMessageCountProvider(widget.eventId));
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    refreshIndicatorsTimer.cancel();
    super.dispose();
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

  Future<void> _showChat() async {
    final lastSeen =
        await ref.read(chatLastSeenProvider(widget.eventId).future);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => EventChatSheet(
        eventId: widget.eventId,
        lastSeen: lastSeen,
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

  Future<void> _saveRsvp(InstanceMemberStatus? status, Instance instance,
      {String? note}) async {
    try {
      final rsvpsController = ref.read(rsvpsProvider.notifier);
      final savedRsvp =
          await rsvpsController.save(instance, status, note: note);

      // start or stop tracking
      final locationController = ref.read(locationControllerProvider);
      if (status == InstanceMemberStatus.omw) {
        await locationController.startTracking(instance.id!);
      } else {
        await locationController.stopTracking(instance.id!);
      }

      if (rsvpSnackbar != null) {
        try {
          rsvpSnackbar!.close();
        } catch (error, stackTrace) {
          logger.e('Failed to close rsvpSnackbar',
              error: error, stackTrace: stackTrace);
        }
        rsvpSnackbar = null;
      }

      if (mounted) {
        rsvpSnackbar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            savedRsvp == null
                ? 'You\'ve removed your RSVP'
                : 'You\'ve RSVPed ${savedRsvp.status.name}',
          ),
        ));
      }

      rsvpSnackbar?.closed.then((reason) {
        rsvpSnackbar = null;
      });
    } catch (error, stackTrace) {
      logger.e("EventDetailsScreen._saveRsvp: error",
          error: error, stackTrace: stackTrace);
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
        note: myRsvp?.note,
        onStatusSelected: (status, note) {
          _saveRsvp(status, event, note: note);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));
    final myRsvp = ref.watch(myRsvpPerEventProvider(widget.eventId));

    return AppScaffold(
      showAppBar: false,
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (event) => RefreshIndicator(
          displacement: 100,
          onRefresh: () async {
            ref.invalidate(eventDetailsProvider(widget.eventId));
            ref.invalidate(rsvpsPerEventProvider(widget.eventId));
            ref.invalidate(eventPointsProvider(widget.eventId));
            ref.invalidate(chatMessageCountProvider(widget.eventId));
            ref.invalidate(chatProvider(widget.eventId));
            ref.invalidate(latestPinnedMessageProvider(widget.eventId));
          },
          child: CustomScrollView(
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, child) {
                      return EventQuickActions(
                        selectedStatus: myRsvp.valueOrNull?.status,
                        eventId: widget.eventId,
                        onRsvpTap: () => _showRsvpSheet(event),
                        onMapTap: _showLiveMap,
                        onShareTap: _copyEventLink,
                        onChatTap: _showChat,
                        showChat: myRsvp.valueOrNull != null,
                      );
                    },
                  ),
                ),
              ),

              // Host Bulletin
              EventHostBulletin(
                eventId: widget.eventId,
                onTap: () => _showChat(),
              ),

              // Event Description
              if (event.notes != null && event.notes!.trim().isNotEmpty)
                EventDescription(description: event.notes),

              // Event Info
              EventInfo(event: event),

              // Attendees
              EventAttendees(
                event: event,
                currentUserId: session!.user.id,
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
    );
  }
}
