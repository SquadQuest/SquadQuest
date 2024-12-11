import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/contacts.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/models/friend.dart';
// import 'package:squadquest/components/tiles/profile.dart';
import 'package:squadquest/components/phone_number_field.dart';
import 'package:squadquest/components/contacts_list.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  static final _requestDateFormat = DateFormat('MMM d, h:mm a');

  Future<void> _showAddFriendDialog() async {
    final method = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('By Phone Number'),
                onTap: () {
                  Navigator.of(context).pop('phone');
                },
              ),
              ListTile(
                leading: const Icon(Icons.contacts),
                title: const Text('From Contacts'),
                onTap: () {
                  Navigator.of(context).pop('contacts');
                },
              ),
            ],
          ),
        );
      },
    );

    if (method == null) return;

    if (!mounted) return;

    if (method == 'phone') {
      _sendFriendRequest(context, AddFriendMethod.number);
    } else {
      _sendFriendRequest(context, AddFriendMethod.contacts);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Friends Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add friends to plan activities together and see what they\'re up to!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Your First Friend'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsSection(BuildContext context, List<Friend> requests) {
    if (requests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text(
                  'Friend Requests',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    requests.length.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...requests.map((friend) {
            final requester = friend.requester!;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(requester.firstName[0]),
              ),
              title: Text('${requester.firstName} ${requester.lastName}'),
              subtitle: Text(
                  '${friend.mutualFriendCount} mutual friends • ${_requestDateFormat.format(friend.createdAt!)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () =>
                        _respondFriendRequest(context, friend, false),
                    child: const Text('Ignore'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        _respondFriendRequest(context, friend, true),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, List<Friend> friends) {
    return Column(
      children: friends.map((friend) {
        final profile =
            friend.getOtherProfile(ref.read(authControllerProvider)!.user.id)!;

        // TODO: Uncomment when backend is ready
        // final isOnline = profile.lastSeenAt != null &&
        //     DateTime.now().difference(profile.lastSeenAt!) <
        //         const Duration(minutes: 5);
        // String status;
        // if (isOnline) {
        //   status = profile.currentActivity ?? 'Online';
        // } else if (profile.lastSeenAt != null) {
        //   final difference = DateTime.now().difference(profile.lastSeenAt!);
        //   if (difference.inMinutes < 60) {
        //     status = 'Last seen ${difference.inMinutes}m ago';
        //   } else if (difference.inHours < 24) {
        //     status = 'Last seen ${difference.inHours}h ago';
        //   } else {
        //     status = 'Last seen ${difference.inDays}d ago';
        //   }
        // } else {
        //   status = 'Offline';
        // }

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: profile.photo != null
                    ? NetworkImage(profile.photo!.toString())
                    : null,
                child:
                    profile.photo == null ? Text(profile.firstName[0]) : null,
              ),
              // TODO: Uncomment when backend is ready
              // if (isOnline)
              //   Positioned(
              //     right: 0,
              //     bottom: 0,
              //     child: Container(
              //       width: 12,
              //       height: 12,
              //       decoration: BoxDecoration(
              //         color: Colors.green,
              //         border: Border.all(
              //           color: Theme.of(context).scaffoldBackgroundColor,
              //           width: 2,
              //         ),
              //         borderRadius: BorderRadius.circular(6),
              //       ),
              //     ),
              //   ),
            ],
          ),
          title: Text('${profile.firstName} ${profile.lastName}'),
          // TODO: Uncomment when backend is ready
          // subtitle: Text(
          //   status,
          //   style: TextStyle(
          //     color: isOnline
          //         ? Theme.of(context).colorScheme.primary
          //         : Theme.of(context).textTheme.bodySmall?.color,
          //   ),
          // ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
          onTap: () {
            context
                .pushNamed('profile-view', pathParameters: {'id': profile.id});
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final friendsList = ref.watch(friendsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppScaffold(
      title: 'Friends',
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.read(friendsProvider.notifier).refresh();
        },
        child: friendsList.when(
          data: (friends) {
            if (friends.isEmpty) {
              return _buildEmptyState(context);
            }

            final requests = friends
                .where((f) =>
                    f.status == FriendStatus.requested &&
                    f.requestee?.id == session.user.id)
                .toList();
            final acceptedFriends = friends
                .where((f) => f.status == FriendStatus.accepted)
                .toList();

            return CustomScrollView(
              slivers: [
                // Friend Requests Section
                SliverToBoxAdapter(
                  child: _buildRequestsSection(context, requests),
                ),

                // Friends List Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Friends',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _showAddFriendDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Friend'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFriendsList(context, acceptedFriends),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  void _respondFriendRequest(
      BuildContext context, Friend friend, bool accept) async {
    try {
      await ref.read(friendsProvider.notifier).respondToFriendRequest(
          friend, accept ? FriendStatus.accepted : FriendStatus.declined);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            accept ? 'Friend request accepted!' : 'Friend request declined'),
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to respond to friend request:\n\n$error'),
      ));
    }
  }

  void _sendFriendRequest(BuildContext context, AddFriendMethod method) async {
    String? phone;
    Contact? contact;

    switch (method) {
      case AddFriendMethod.number:
        phone = await _showPhoneNumberPicker();
      case AddFriendMethod.contacts:
        contact = await _showContactPicker();
        if (contact != null) {
          try {
            phone = normalizePhone(contact.phones.first.number);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Could not parse phone nuber: ${contact.phones.first.number}'),
              ));
              return;
            }
          }
        }
    }

    if (phone == null) {
      // dialog cancelled
      return;
    }

    // check if user has an account yet and show invitation confirmation
    try {
      final requesteeProfileResponse = await ref
          .read(supabaseClientProvider)
          .functions
          .invoke('get-profile',
              method: HttpMethod.get, queryParameters: {'phone': phone});

      final requesterProfile = await ref.read(profileProvider.future);

      if (requesteeProfileResponse.data['profile'] == null) {
        if (!context.mounted) return;

        final confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                  title: const Text('Send friend request?'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        'Do you want to send a friend request to ${contact?.displayName ?? phone}?\n\n'
                        'SquadQuest will send them the following message and register their'
                        ' phone number so that if/when they sign up—even if by finding SquadQuest'
                        ' in the app store without using your link—your friend request can'
                        ' automatically added to their new account:'),
                    Container(
                        margin:
                            const EdgeInsets.only(top: 16, right: 8, left: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey)),
                        child: Text(
                            'Hi, ${requesterProfile!.fullName} wants to be your friend on SquadQuest!\n\n'
                            'Download the app at https://squadquest.app'))
                  ]),
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
                ));

        if (confirmed != true) {
          return;
        }
      }
    } catch (error) {
      logger.e(error);
    }

    // create friend request
    try {
      final friendship = await ref
          .read(friendsProvider.notifier)
          .sendFriendRequest(
              phone,
              contact == null
                  ? null
                  : {
                      'first_name': contact.name.first,
                      'last_name': contact.name.last
                    });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendship == null
            ? 'New friend invited to join SquadQuest!\n\nThe pending request won\'t appear in your buddy list until they join.'
            : 'Friend request sent!'),
      ));
    } catch (error) {
      logger.e(error);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send friend request:\n\n$error'),
      ));
      return;
    }
  }

  Future<dynamic> _showContactPicker() async {
    final contactsService = ref.read(contactsProvider.notifier);

    final permissionGranted = await contactsService.requestPermission();

    if (!mounted || permissionGranted == null) {
      return null;
    }

    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => SizedBox(
            height: MediaQuery.of(context).size.height * .75,
            child: const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 16),
                child: ContactsList())));
  }

  Future<dynamic> _showPhoneNumberPicker() async {
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
                    PhoneNumberFormField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone),
                        labelText: 'Enter your friend\'s phone number',
                      ),
                      phoneNumberController: phoneController,
                      onSubmitted: (_) {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        Navigator.of(context).pop(phoneController.text);
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

                              Navigator.of(context).pop(phoneController.text);
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

enum AddFriendMethod { number, contacts }
