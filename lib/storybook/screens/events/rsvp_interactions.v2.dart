import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RsvpInteractionsV2Screen extends ConsumerStatefulWidget {
  const RsvpInteractionsV2Screen({super.key});

  @override
  ConsumerState<RsvpInteractionsV2Screen> createState() =>
      _RsvpInteractionsV2ScreenState();
}

class _RsvpInteractionsV2ScreenState
    extends ConsumerState<RsvpInteractionsV2Screen> {
  bool _showRsvpSheet = false;
  String? _selectedStatus;
  String _note = '';
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showRsvpBottomSheet() {
    setState(() => _showRsvpSheet = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSVP Demo'),
      ),
      body: Stack(
        children: [
          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _showRsvpBottomSheet,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('RSVP to Event'),
                ),
                if (_selectedStatus != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Your RSVP: $_selectedStatus',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_note.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                                  style: Theme.of(context).textTheme.titleSmall,
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
              ],
            ),
          ),

          // RSVP Bottom Sheet
          if (_showRsvpSheet)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Backdrop
                  GestureDetector(
                    onTap: () => setState(() => _showRsvpSheet = false),
                    child: Container(
                      color: Colors.black54,
                      height: MediaQuery.of(context).size.height * 0.4,
                    ),
                  ),

                  // Sheet Content
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'RSVP to Board Game Night',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _showRsvpSheet = false),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // RSVP Options
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRsvpOption(
                                    'Going',
                                    Icons.check_circle,
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  _buildRsvpOption(
                                    'Maybe',
                                    Icons.help,
                                    Theme.of(context).colorScheme.secondary,
                                  ),
                                  _buildRsvpOption(
                                    'Not Going',
                                    Icons.cancel,
                                    Theme.of(context).colorScheme.error,
                                  ),
                                  const Divider(),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Add a Note (Optional)',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRsvpOption(String label, IconData icon, Color color) {
    final isSelected = _selectedStatus == label;

    return ListTile(
      leading: Icon(
        icon,
        color:
            isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(label),
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      onTap: () {
        setState(() {
          _selectedStatus = label;
          _note = _noteController.text;
          _showRsvpSheet = false;
        });
      },
    );
  }
}
