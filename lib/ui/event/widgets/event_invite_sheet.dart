import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/logger.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/controllers/rsvps.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';

import 'package:squadquest/ui/core/widgets/app_bottom_sheet.dart';

class EventInviteSheet extends ConsumerStatefulWidget {
  final InstanceID eventId;
  final List<UserID> excludeUsers;

  const EventInviteSheet({
    super.key,
    required this.eventId,
    this.excludeUsers = const <UserID>[],
  });

  @override
  ConsumerState<EventInviteSheet> createState() => _EventInviteSheetState();
}

class _EventInviteSheetState extends ConsumerState<EventInviteSheet> {
  String _searchQuery = '';
  final List<UserID> _selectedUsers = [];
  bool _submitting = false;

  void _onSearchQueryChanged(String searchQuery) {
    setState(() {
      _searchQuery = searchQuery.toLowerCase();
    });
  }

  Future<void> _inviteSelectedUsers() async {
    // Inviting is a slow round trip (several queries plus a push per invitee),
    // so a second tap used to land while the first was still in flight. The
    // retry then found every invitation already created and failed, even
    // though the first tap had worked.
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final sentInvitations = await ref
          .read(rsvpsProvider.notifier)
          .invite(widget.eventId, _selectedUsers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Invited ${sentInvitations.length} ${sentInvitations.length == 1 ? 'friend' : 'friends'}'),
        ));
        Navigator.of(context).pop();
      }
    } catch (error) {
      logger.e('Failed to invite friends', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to invite friends: $error'),
        ));
      }
    } finally {
      // skipped on success, where the pop above already unmounted the sheet
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final friendsList = ref.watch(friendsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PopScope(
      canPop: !_submitting,
      child: AppBottomSheet(
        title: 'Invite Friends',
        bottomPaddingInsetExtra: 16,
        bottomPaddingMin: 16,
        children: [
          TextFormField(
            enabled: !_submitting,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search friends',
            ),
            onChanged: _onSearchQueryChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: friendsList.when(
              data: (friends) {
                final filteredFriends = friends.where((friend) {
                  if (friend.status != FriendStatus.accepted) {
                    return false;
                  }

                  final otherProfile = friend.getOtherProfile(session.user.id)!;

                  if (widget.excludeUsers.contains(otherProfile.id)) {
                    return false;
                  }

                  return _searchQuery.isEmpty ||
                      otherProfile.displayName
                          .toLowerCase()
                          .contains(_searchQuery);
                });

                return filteredFriends.isEmpty
                    ? const Text(
                        'No friends found who haven\'t already been invited')
                    : ListView(
                        children: filteredFriends.map((friend) {
                          final otherProfile =
                              friend.getOtherProfile(session.user.id);

                          return CheckboxListTile(
                            title: Text(otherProfile!.displayName),
                            value: _selectedUsers.contains(otherProfile.id),
                            onChanged: _submitting
                                ? null
                                : (bool? value) {
                                    setState(() {
                                      if (value!) {
                                        _selectedUsers.add(otherProfile.id);
                                      } else {
                                        _selectedUsers.remove(otherProfile.id);
                                      }
                                      FocusScope.of(context).unfocus();
                                    });
                                  },
                          );
                        }).toList(),
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedUsers.isEmpty || _submitting
                      ? null
                      : _inviteSelectedUsers,
                  child: _submitting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Inviting\u2026'),
                          ],
                        )
                      : const Text('Invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
