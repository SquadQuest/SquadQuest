import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/models/user.dart';

class FriendsList extends ConsumerStatefulWidget {
  final String title;
  final String emptyText;
  final FriendStatus? status;
  final List<UserID> excludeUsers;

  const FriendsList(
      {super.key,
      this.title = 'Find friends',
      this.emptyText = 'No friends found',
      this.status,
      this.excludeUsers = const <UserID>[]});

  @override
  ConsumerState<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends ConsumerState<FriendsList> {
  String _searchQuery = '';
  final List<UserID> _selectedUsers = [];

  void _onSearchQueryChanged(String searchQuery) {
    setState(() {
      _searchQuery = searchQuery.toLowerCase();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final friendsList = ref.watch(friendsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * .75,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: Column(
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search friends',
              ),
              onChanged: _onSearchQueryChanged,
            ),
            const SizedBox(height: 32),
            Expanded(
                child: friendsList.when(
                    data: (friends) {
                      final filteredFriends = friends.where((friend) {
                        if (widget.status != null &&
                            friend.status != widget.status) {
                          return false;
                        }

                        final otherProfile =
                            friend.getOtherProfile(session.user.id)!;

                        if (widget.excludeUsers.contains(otherProfile.id)) {
                          return false;
                        }

                        return _searchQuery.isEmpty ||
                            otherProfile.displayName
                                .toLowerCase()
                                .contains(_searchQuery);
                      });

                      return filteredFriends.isEmpty
                          ? Text(widget.emptyText)
                          : ListView(
                              shrinkWrap: true,
                              children: filteredFriends.map((friend) {
                                final otherProfile =
                                    friend.getOtherProfile(session.user.id);

                                return CheckboxListTile(
                                  title: Text(otherProfile!.displayName),
                                  value:
                                      _selectedUsers.contains(otherProfile.id),
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
                              }).toList());
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('Error: $error'))),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_selectedUsers);
                },
                child: const Text('Invite'),
              ),
              const SizedBox(width: 16),
            ]),
          ],
        ),
      ),
    );
  }
}
