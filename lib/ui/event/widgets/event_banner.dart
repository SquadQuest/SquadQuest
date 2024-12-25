import 'package:flutter/material.dart';
import 'package:fullscreen_image_viewer/fullscreen_image_viewer.dart';
import 'package:intl/intl.dart';

import 'package:squadquest/models/instance.dart';

enum EventHostAction { setRallyPoint, edit, cancel, uncancel, duplicate }

const eventBannerExpandedHeight = 200.0;

class EventBanner extends StatelessWidget {
  final Instance event;
  final bool isCollapsed;
  final String? currentUserId;
  final void Function(EventHostAction action)? onHostAction;

  const EventBanner({
    super.key,
    required this.event,
    required this.isCollapsed,
    this.currentUserId,
    this.onHostAction,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: eventBannerExpandedHeight,
      floating: false,
      pinned: true,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isCollapsed ? 1.0 : 0.0,
        child: Text(event.title,
            style: TextStyle(
              overflow: TextOverflow.ellipsis,
              decoration: event.status == InstanceStatus.canceled
                  ? TextDecoration.lineThrough
                  : null,
            )),
      ),
      actions: [
        if (event.createdById == currentUserId) ...[
          PopupMenuButton<EventHostAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: onHostAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: EventHostAction.setRallyPoint,
                child: ListTile(
                  leading: const Icon(Icons.pin_drop_outlined),
                  title: event.rallyPoint == null
                      ? const Text('Set rally point')
                      : const Text('Update rally point'),
                ),
              ),
              const PopupMenuItem(
                value: EventHostAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit event'),
                ),
              ),
              PopupMenuItem(
                value: event.status == InstanceStatus.canceled
                    ? EventHostAction.uncancel
                    : EventHostAction.cancel,
                child: ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: event.status == InstanceStatus.canceled
                      ? const Text('Uncancel event')
                      : const Text('Cancel event'),
                ),
              ),
              const PopupMenuItem(
                value: EventHostAction.duplicate,
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Duplicate event'),
                ),
              ),
            ],
          ),
        ],
      ],
      flexibleSpace: GestureDetector(
        onLongPress: () {
          FullscreenImageViewer.open(
            context: context,
            child: Hero(
              tag: 'event-banner-${event.id}',
              child: Image.network(
                event.bannerPhoto.toString(),
              ),
            ),
          );
        },
        child: FlexibleSpaceBar(
          background: Stack(
            fit: StackFit.expand,
            children: [
              if (event.bannerPhoto != null)
                Hero(
                  tag: 'event-banner-${event.id}',
                  child: Image.network(
                    event.bannerPhoto.toString(),
                    fit: BoxFit.cover,
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(180),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        decoration: event.status == InstanceStatus.canceled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('E, MMM d').format(event.startTimeMin)} • Starts ${DateFormat('h:mm a').format(event.startTimeMin)}-${DateFormat('h:mm a').format(event.startTimeMax)}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.locationDescription,
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
