import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';

class EventDetailsV3Screen extends ConsumerStatefulWidget {
  const EventDetailsV3Screen({super.key});

  @override
  ConsumerState<EventDetailsV3Screen> createState() =>
      _EventDetailsV3ScreenState();
}

class _EventDetailsV3ScreenState extends ConsumerState<EventDetailsV3Screen> {
  InstanceMemberStatus? _selectedStatus;
  String _note = '';
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showRsvpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'RSVP to Board Game Night',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildRsvpOption(
                  status: InstanceMemberStatus.omw,
                  icon: Icons.directions_run,
                  title: "I'm on my way!",
                  subtitle: "Let others know you're heading there",
                ),
                _buildRsvpOption(
                  status: InstanceMemberStatus.yes,
                  icon: Icons.check_circle,
                  title: "I'm going",
                  subtitle: "You'll get updates about this event",
                ),
                _buildRsvpOption(
                  status: InstanceMemberStatus.maybe,
                  icon: Icons.help,
                  title: "Maybe",
                  subtitle: "You'll still get updates about this event",
                ),
                _buildRsvpOption(
                  status: InstanceMemberStatus.no,
                  icon: Icons.cancel,
                  title: "Can't make it",
                  subtitle: "You won't get further updates",
                ),
                const SizedBox(height: 16),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add a Note (Optional)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          hintText:
                              'e.g., "Bringing snacks!" or "Running late"',
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (_selectedStatus != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _note = '';
                        _noteController.clear();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text("Remove RSVP"),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRsvpOption({
    required InstanceMemberStatus status,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedStatus == status;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _note = _noteController.text;
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = context.knobs.boolean(
      label: 'Event is cancelled',
      initial: false,
      description: 'Show event in cancelled state',
    );

    final showBulletin = context.knobs.boolean(
      label: 'Show host bulletin',
      initial: false,
      description: 'Show the latest pinned message from host',
    );

    final showEndTime = context.knobs.boolean(
      label: 'Show end time',
      initial: true,
      description: 'Show optional end time for event',
    );

    final showMap = context.knobs.boolean(
      label: 'Show map preview',
      initial: false,
      description: 'Show the location map preview',
    );

    return AppScaffold(
      title: 'Board Game Night',
      titleStyle: isCancelled
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
      body: CustomScrollView(
        slivers: [
          // Banner Image with Overlay
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://picsum.photos/800/400',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Board Game Night',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            decoration:
                                isCancelled ? TextDecoration.lineThrough : null,
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
                              'Friday, March 15 • Starts 7:00-7:30 PM',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
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
                              'Game Knight Lounge',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
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

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isCancelled)
                  Container(
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
                                  color: Colors.red.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions from v1
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: _showRsvpSheet,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedStatus == null
                                          ? Icons.check_circle_outline
                                          : _selectedStatus ==
                                                  InstanceMemberStatus.omw
                                              ? Icons.directions_run
                                              : _selectedStatus ==
                                                      InstanceMemberStatus.yes
                                                  ? Icons.check_circle
                                                  : _selectedStatus ==
                                                          InstanceMemberStatus
                                                              .maybe
                                                      ? Icons.help
                                                      : Icons.cancel,
                                      size: 24,
                                      color: _selectedStatus != null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedStatus?.name.toUpperCase() ??
                                          'RSVP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _selectedStatus != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () {},
                              child: Container(
                                width: 64,
                                height: 64,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.map_outlined, size: 24),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Map',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () {},
                              child: Container(
                                width: 64,
                                height: 64,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.share_outlined, size: 24),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Share',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () {},
                              child: Container(
                                width: 64,
                                height: 64,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.chat_bubble_outline,
                                        size: 24),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Chat',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (showMap)
                        AspectRatio(
                          aspectRatio: 2,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.map, size: 32),
                            ),
                          ),
                        ),

                      if (_note.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.note_alt, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Note',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_note),
                            ],
                          ),
                        ),

                      if (showBulletin)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                'We\'ll be in the back room, look for the SquadQuest sign!',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '2 hours ago',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // About section from v1
                      _buildSection(
                        title: 'About',
                        child: const Text(
                          'Join us for a night of strategy and fun! We\'ll have a variety of games available, from quick party games to longer strategy games. Beginners welcome! Food and drinks available for purchase.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Event Info section
                      _buildSection(
                        title: 'Event Info',
                        child: Column(
                          children: [
                            _buildInfoRow(
                              context,
                              icon: Icons.person,
                              label: 'Posted by',
                              value: 'Sarah Chen',
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              context,
                              icon: Icons.schedule,
                              label: 'Time',
                              value: 'Starts between 7:00-7:30 PM',
                              secondaryValue:
                                  showEndTime ? 'Ends around 10:00 PM' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              context,
                              icon: Icons.visibility,
                              label: 'Visibility',
                              value: 'Friends Only',
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              context,
                              icon: Icons.category,
                              label: 'Topic',
                              value: 'Board Games',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Detailed attendee sections from v2
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

          // Attendee sections from v2
          _buildAttendeeSection(
            context,
            title: 'On My Way',
            attendees: [
              _Attendee(
                name: 'Mike Johnson',
                imageUrl: 'https://i.pravatar.cc/300?u=mike',
                subtitle: '5 minutes away',
              ),
              _Attendee(
                name: 'Emma Wilson',
                imageUrl: 'https://i.pravatar.cc/300?u=emma',
                subtitle: '2 minutes away',
                isCurrentUser: true,
                rsvpNote: 'Can\'t wait! I\'ll help set up the tables.',
              ),
            ],
            color: Theme.of(context).colorScheme.tertiary,
          ),

          _buildAttendeeSection(
            context,
            title: 'Going',
            attendees: [
              _Attendee(
                name: 'Sarah Chen',
                imageUrl: 'https://i.pravatar.cc/300?u=sarah',
                subtitle: 'Host',
                isHost: true,
              ),
              _Attendee(
                name: 'Alex Rivera',
                imageUrl: 'https://i.pravatar.cc/300?u=alex',
                subtitle: 'Friend',
                rsvpNote: 'Bringing snacks and drinks!',
              ),
            ],
            color: Theme.of(context).colorScheme.primary,
          ),

          _buildAttendeeSection(
            context,
            title: 'Maybe',
            attendees: [
              _Attendee(
                name: 'Chris Brown',
                imageUrl: 'https://i.pravatar.cc/300?u=chris',
                subtitle: 'Friend',
                rsvpNote: 'Will confirm by Thursday',
              ),
            ],
            color: Theme.of(context).colorScheme.secondary,
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildAttendeeSection(
    BuildContext context, {
    required String title,
    required List<_Attendee> attendees,
    required Color color,
  }) {
    if (attendees.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          attendees.length.toString(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              ...attendees.map(
                  (attendee) => _buildAttendeeItem(context, attendee, color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? secondaryValue,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (secondaryValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryValue,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendeeItem(
      BuildContext context, _Attendee attendee, Color sectionColor) {
    return Container(
      decoration: BoxDecoration(
        color: attendee.isCurrentUser
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(attendee.imageUrl),
            ),
            title: Row(
              children: [
                Text(attendee.name),
                if (attendee.isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'You',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    ),
                  ),
                ],
                if (attendee.isHost) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sectionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Host',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(attendee.subtitle),
          ),
          if (attendee.rsvpNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attendee.rsvpNote!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

class _Attendee {
  final String name;
  final String imageUrl;
  final String subtitle;
  final bool isHost;
  final bool isCurrentUser;
  final String? rsvpNote;

  const _Attendee({
    required this.name,
    required this.imageUrl,
    required this.subtitle,
    this.isHost = false,
    this.isCurrentUser = false,
    this.rsvpNote,
  });
}
