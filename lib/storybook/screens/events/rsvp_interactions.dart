import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/instance.dart';

class RsvpInteractionsScreen extends ConsumerStatefulWidget {
  const RsvpInteractionsScreen({super.key});

  @override
  ConsumerState<RsvpInteractionsScreen> createState() =>
      _RsvpInteractionsScreenState();
}

class _RsvpInteractionsScreenState
    extends ConsumerState<RsvpInteractionsScreen> {
  InstanceMemberStatus? _selectedStatus;
  String _note = '';
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showRsvpSheet(bool showNoteField) {
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
                if (showNoteField) ...[
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                ],
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

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(
              icon: Icons.map,
              title: 'Open live map',
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.chat,
              title: 'Open chat',
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.link,
              title: 'Get link',
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            _buildOptionTile(
              icon: Icons.edit,
              title: 'Edit event',
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.copy,
              title: 'Duplicate event',
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.cancel,
              title: 'Cancel event',
              onTap: () => Navigator.pop(context),
              isDestructive: true,
            ),
          ],
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

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showNoteField = context.knobs.boolean(
      label: 'Show note field',
      initial: false,
      description: 'Toggle optional note field in RSVP sheet',
    );

    return AppScaffold(
      title: 'RSVP Interactions',
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Banner Image with RSVP Button
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
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Board Game Night',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () => _showRsvpSheet(showNoteField),
                              child: Text(_selectedStatus == null
                                  ? 'RSVP'
                                  : _selectedStatus!.name.toUpperCase()),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Tap the RSVP button in the banner above or the buttons below to see the interactions',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      if (_note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.note_alt, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Your Note',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(_note),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _showRsvpSheet(showNoteField),
                      child: Text(_selectedStatus == null
                          ? 'RSVP'
                          : _selectedStatus!.name.toUpperCase()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _showOptionsSheet,
                    icon: const Icon(Icons.more_vert),
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
