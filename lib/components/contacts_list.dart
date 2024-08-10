import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadquest/common.dart';
import 'package:squadquest/services/contacts.dart';

export 'package:flutter_contacts/flutter_contacts.dart' show Contact;

class ContactsList extends ConsumerStatefulWidget {
  const ContactsList({super.key});
  @override
  ConsumerState<ContactsList> createState() => _ContactsListState();
}

class _ContactsListState extends ConsumerState<ContactsList> {
  String _query = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final contactsService = ref.read(contactsProvider.notifier);
    final contacts = ref.watch(contactsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            autofocus: true,
            onChanged: (query) {
              setState(() {
                _query = query.toLowerCase().trim();
              });
            },
            decoration: const InputDecoration(
              labelText: 'Search Contacts',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        contactsService.permissionGranted != true
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Permission to read contacts has not been granted'))
            : contacts.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load contacts: $error')),
                data: (contacts) {
                  // filter down to contacts with phone numbers that optionally match query
                  final filteredContacts = contacts
                      .where((contact) =>
                          contact.phones.isNotEmpty &&
                          (_query.isEmpty ||
                              contact.displayName
                                  .toLowerCase()
                                  .contains(_query)))
                      .toList();

                  if (filteredContacts.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No contacts found'));
                  }

                  return Expanded(
                      child: ListView.builder(
                    itemCount: filteredContacts.length,
                    prototypeItem: const ListTile(
                      title: Text('First Last'),
                    ),
                    itemBuilder: (context, index) {
                      Contact contact = filteredContacts[index];
                      return ListTile(
                        onTap: () {
                          Navigator.of(context).pop(contact);
                        },
                        leading: CircleAvatar(
                          backgroundImage: contact.photoOrThumbnail != null
                              ? MemoryImage(contact.photoOrThumbnail!)
                              : null,
                        ),
                        title: Text(contact.displayName),
                        subtitle:
                            Text(formatPhone(contact.phones.first.number)),
                      );
                    },
                  ));
                },
              ),
      ],
    );
  }
}
