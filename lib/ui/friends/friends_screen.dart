import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/models/friend.dart';
import 'package:squadquest/services/contacts.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/controllers/auth.dart';
import 'package:squadquest/controllers/friends.dart';
import 'package:squadquest/controllers/profile.dart';
import 'package:squadquest/components/phone_number_field.dart';
import 'package:squadquest/components/contacts_list.dart';

import 'widgets/add_friend_dialog.dart';
import 'widgets/friends_empty_state.dart';
import 'widgets/friend_requests_section.dart';
import 'widgets/friends_list_section.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  Future<void> _showPhoneNumberPicker(BuildContext context) async {
    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
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
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  PhoneNumberFormField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.phone),
                      labelText: 'Enter your friend\'s phone number',
                    ),
                    phoneNumberController: phoneController,
                    onSubmitted: (_) {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.of(context).pop(phoneController.text);
                    },
                  ),
                  const SizedBox(height: 32),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 16,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(phoneController.text);
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (phoneNumber == null) return;

    if (!context.mounted) return;
    await _sendFriendRequest(context, phoneNumber);
  }

  Future<void> _showContactPicker(BuildContext context, WidgetRef ref) async {
    final contactsService = ref.read(contactsProvider.notifier);
    final permissionGranted = await contactsService.requestPermission();

    if (!context.mounted || permissionGranted == null) return;

    final contact = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: const Padding(
          padding: EdgeInsets.only(top: 0, bottom: 16),
          child: ContactsList(),
        ),
      ),
    );

    if (contact == null) return;

    String? phone;
    try {
      phone = normalizePhone(contact.phones.first.number);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not parse phone number: ${contact.phones.first.number}'),
        ));
      }
      return;
    }

    if (!context.mounted) return;
    await _sendFriendRequest(context, phone, contact: contact);
  }

  Future<void> _sendFriendRequest(BuildContext context, String phone,
      {Contact? contact}) async {
    final ref = ProviderScope.containerOf(context);
    final session = ref.read(authControllerProvider);
    final profile = await ref.read(profileProvider.future);
    if (session == null || profile == null) return;

    try {
      final requesteeProfileResponse = await ref
          .read(supabaseClientProvider)
          .functions
          .invoke('get-profile',
              method: HttpMethod.get, queryParameters: {'phone': phone});

      if (requesteeProfileResponse.data['profile'] == null) {
        if (!context.mounted) return;

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Send friend request?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Do you want to send a friend request to ${contact?.displayName ?? phone}?\n\n'
                  'SquadQuest will send them the following message and register their'
                  ' phone number so that if/when they sign up—even if by finding SquadQuest'
                  ' in the app store without using your link—your friend request can'
                  ' automatically added to their new account:',
                ),
                Container(
                  margin: const EdgeInsets.only(top: 16, right: 8, left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Text(
                    'Hi, ${profile.fullName} wants to be your friend on SquadQuest!\n\n'
                    'Download the app at https://squadquest.app',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      if (!context.mounted) return;

      final friendship =
          await ref.read(friendsProvider.notifier).sendFriendRequest(
              phone,
              contact == null
                  ? null
                  : {
                      'first_name': contact.name.first,
                      'last_name': contact.name.last,
                    });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendship == null
            ? 'New friend invited to join SquadQuest!\n\nThe pending request won\'t appear in your buddy list until they join.'
            : 'Friend request sent!'),
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send friend request:\n\n$error'),
      ));
    }
  }

  Future<void> _showAddFriendDialog(BuildContext context, WidgetRef ref) async {
    final method = await showDialog<AddFriendMethod>(
      context: context,
      builder: (BuildContext context) => const AddFriendDialog(),
    );

    if (method == null) return;

    if (!context.mounted) return;

    switch (method) {
      case AddFriendMethod.number:
        await _showPhoneNumberPicker(context);
      case AddFriendMethod.contacts:
        await _showContactPicker(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              return FriendsEmptyState(
                onAddFriend: () => _showAddFriendDialog(context, ref),
              );
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
                  child: FriendRequestsSection(
                    requests: requests,
                    onRespond: (friend, accept) async {
                      try {
                        await ref
                            .read(friendsProvider.notifier)
                            .respondToFriendRequest(
                                friend,
                                accept
                                    ? FriendStatus.accepted
                                    : FriendStatus.declined);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(accept
                              ? 'Friend request accepted!'
                              : 'Friend request declined'),
                        ));
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Failed to respond to friend request:\n\n$error'),
                        ));
                      }
                    },
                  ),
                ),

                // Friends List Section
                SliverToBoxAdapter(
                  child: FriendsListSection(
                    friends: acceptedFriends,
                    currentUserId: session.user.id,
                    onAddFriend: () => _showAddFriendDialog(context, ref),
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
}
