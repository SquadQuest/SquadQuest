import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/contacts.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/components/tiles/profile.dart';
import 'package:squadquest/components/phone_number_field.dart';
import 'package:squadquest/components/contacts_list.dart';

final _statusGroupOrder = {
  FriendStatus.requested: 0,
  FriendStatus.accepted: 1,
  FriendStatus.declined: 2,
};

enum AddFriendMethod { number, contacts }

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  static final _requestDateFormat = DateFormat('MMM d, h:mm a');
  final _fabKey = GlobalKey<ExpandableFabState>();

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final friendsList = ref.watch(friendsProvider);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppScaffold(
      title: 'Buddy List',
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: _fabKey,
        type: ExpandableFabType.up,
        distance: 80,
        childrenAnimation: ExpandableFabAnimation.none,
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.black.withOpacity(0.75),
          blur: 5,
        ),
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          child: const Icon(Icons.add_reaction),
        ),
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: const Icon(Icons.close),
        ),
        children: [
          Row(
            children: [
              const Text('By Phone Number'),
              const SizedBox(width: 20),
              FloatingActionButton(
                heroTag: null,
                onPressed: () =>
                    _sendFriendRequest(context, AddFriendMethod.number),
                child: const Icon(Icons.pin_outlined),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Search Contacts'),
              const SizedBox(width: 20),
              FloatingActionButton(
                heroTag: null,
                onPressed: () =>
                    _sendFriendRequest(context, AddFriendMethod.contacts),
                child: const Icon(Icons.search),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.read(friendsProvider.notifier).refresh();
        },
        child: friendsList.when(
            data: (friends) => Stack(children: [
                  if (friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'You have no friends yet! Get a friend to join SquadQuest and then send a request via their phone number with the button below.',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  GroupedListView(
                    elements: friends,
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
                      final friendProfile =
                          friend.getOtherProfile(session.user.id);
                      return ProfileTile(
                          profile: friendProfile!,
                          onTap: friend.status == FriendStatus.accepted ||
                                  (friend.status == FriendStatus.requested &&
                                      friend.requestee!.id == session.user.id)
                              ? () {
                                  context.pushNamed('profile-view',
                                      pathParameters: {
                                        'id': friendProfile!.id
                                      });
                                }
                              : null,
                          subtitle: switch (friend.status) {
                            FriendStatus.requested => switch (
                                  friend.requester!.id == session.user.id) {
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
                                  friend.requestee?.id == session.user.id
                              ? IconButton.filledTonal(
                                  icon: const Icon(Icons.next_plan_outlined),
                                  onPressed: () =>
                                      _respondFriendRequest(context, friend),
                                )
                              : friendStatusIcons[friend.status]);
                    },
                    itemComparator: (friend1, friend2) =>
                        friend2.createdAt!.compareTo(friend1.createdAt!),
                  )
                ]),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Error: $error'))),
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

  void _sendFriendRequest(BuildContext context, AddFriendMethod method) async {
    final fabState = _fabKey.currentState;
    if (fabState != null && fabState.isOpen) {
      fabState.toggle();
    }

    String? phone;
    Contact? contact;

    switch (method) {
      case AddFriendMethod.number:
        phone = await _showPhoneNumberPicker();
      case AddFriendMethod.contacts:
        contact = await _showContactPicker();
        if (contact != null) {
          phone = contact.phones.first.number;
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
