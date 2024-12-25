import 'dart:math';

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

  void _onSearchQueryChanged(String searchQuery) {
    setState(() {
      _searchQuery = searchQuery.toLowerCase();
    });
  }

  Future<void> _inviteSelectedUsers() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final friendsList = ref.watch(friendsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppBottomSheet(
      title: 'Invite Friends',
      bottomPaddingInsetExtra: 16,
      bottomPaddingMin: 16,
      children: [
        TextFormField(
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
                          onChanged: (bool? value) {
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedUsers.isEmpty ? null : _inviteSelectedUsers,
                child: const Text('Invite'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
