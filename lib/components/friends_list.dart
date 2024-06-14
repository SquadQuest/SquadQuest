import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/controllers/auth.dart';
import 'package:squad_quest/controllers/friends.dart';
import 'package:squad_quest/models/friend.dart';
import 'package:squad_quest/models/user.dart';

class FriendsList extends ConsumerStatefulWidget {
  final FriendStatus? status;

  const FriendsList({super.key, this.status});

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
    final myUser = ref.watch(userProvider);
    final friendsList = ref.watch(friendsProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * .75,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: Column(
          // mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send friend request',
                style: Theme.of(context).textTheme.titleLarge),
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
                    data: (friends) => ListView(
                        shrinkWrap: true,
                        children: friends.where((friend) {
                          if (widget.status != null &&
                              friend.status != widget.status) {
                            return false;
                          }

                          final otherProfile =
                              friend.getOtherProfile(myUser!.id);

                          return _searchQuery.isEmpty ||
                              otherProfile!.fullName
                                  .toLowerCase()
                                  .contains(_searchQuery);
                        }).map((friend) {
                          final otherProfile =
                              friend.getOtherProfile(myUser!.id);

                          return CheckboxListTile(
                            title: Text(otherProfile!.fullName),
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
                        }).toList()),
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
