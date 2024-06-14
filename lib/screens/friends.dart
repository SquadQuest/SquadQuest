import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/drawer.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/models/friend.dart';

final _statusGroupOrder = {
  FriendStatus.requested: 0,
  FriendStatus.accepted: 1,
  FriendStatus.declined: 2,
};

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  static final _requestDateFormat = DateFormat('MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    final myUser = ref.watch(userProvider);
    final friendsList = ref.watch(friendsProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buddy List'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _sendFriendRequest(context),
          child: const Icon(Icons.person_add),
        ),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: () async {
            return ref.read(friendsProvider.notifier).refresh();
          },
          child: friendsList.when(
              data: (friends) {
                return GroupedListView(
                  elements: myUser == null ? <Friend>[] : friends,
                  physics: const AlwaysScrollableScrollPhysics(),
                  useStickyGroupSeparators: true,
                  // floatingHeader: true,
                  stickyHeaderBackgroundColor:
                      Theme.of(context).scaffoldBackgroundColor,
                  groupBy: (Friend friend) => friend.status,
                  groupComparator: (group1, group2) {
                    return _statusGroupOrder[group1]!
                        .compareTo(_statusGroupOrder[group2]!);
                  },
                  groupSeparatorBuilder: (FriendStatus group) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        switch (group) {
                          FriendStatus.requested => 'Request pending',
                          FriendStatus.accepted => 'My Buddies',
                          FriendStatus.declined => 'Declined',
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      )),
                  itemBuilder: (context, friend) {
                    final friendProfile = friend.getOtherProfile(myUser!.id);
                    return ListTile(
                        leading: friendStatusIcons[friend.status],
                        title: Text(friendProfile!.fullName),
                        subtitle: switch (friend.status) {
                          FriendStatus.requested => switch (
                                friend.requester!.id == myUser.id) {
                              true => Text(
                                  'Request sent ${_requestDateFormat.format(friend.createdAt!)}'),
                              false => Text(
                                  'Request received ${_requestDateFormat.format(friend.createdAt!)}'),
                            },
                          FriendStatus.accepted => null,
                          FriendStatus.declined =>
                            const Text('Request declined'),
                        },
                        trailing: friend.status == FriendStatus.requested &&
                                friend.requestee?.id == myUser.id
                            ? IconButton.filledTonal(
                                icon: const Icon(Icons.next_plan_outlined),
                                onPressed: () =>
                                    _respondFriendRequest(context, friend),
                              )
                            : null);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Error: $error'))),
        ),
      ),
    );
  }

  void _respondFriendRequest(context, Friend friend) async {
    final bool? action = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Respond to friend request'),
            content: Text(
                'Do you want to accept or decline the friend request from ${friend.requester!.firstName} ${friend.requester!.lastName}?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Decline'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Accept'),
              ),
            ],
          );
        });

    if (action == null) {
      // dialog cancelled
      return;
    }

    try {
      await ref.read(friendsProvider.notifier).respondToFriendRequest(
          friend, action ? FriendStatus.accepted : FriendStatus.declined);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to respond to friend request:\n\n$error'),
      ));
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(action ? 'Friend request accepted!' : 'Friend request declined'),
    ));
  }

  void _sendFriendRequest(BuildContext context) async {
    final String? phone = await _showAddFriendDialog();

    if (phone == null) {
      // dialog cancelled
      return;
    }

    try {
      await ref.read(friendsProvider.notifier).sendFriendRequest(phone);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send friend request:\n\n$error'),
      ));
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Friend request sent!'),
    ));
  }

  Future<dynamic> _showAddFriendDialog() async {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          final theme = Theme.of(context);
          final formKey = GlobalKey<FormState>();
          final phoneController = TextEditingController();

          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Send friend request',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      autofocus: true,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone),
                        labelText: 'Enter your friend\'s phone number',
                      ),
                      inputFormatters: [phoneInputFilter],
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            normalizePhone(value).length != 11) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                      controller: phoneController,
                      onFieldSubmitted: (_) {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        Navigator.of(context)
                            .pop(normalizePhone(phoneController.text));
                      },
                    ),
                    const SizedBox(height: 32),
                    OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 16,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              Navigator.of(context)
                                  .pop(normalizePhone(phoneController.text));
                            },
                            child: const Text('Send'),
                          ),
                        ]),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
