import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:squadquest/common.dart';

class ContactsList extends ConsumerStatefulWidget {
  final Function(Contact contact, List<Widget> actions)? confirmBuilder;

  const ContactsList({super.key, this.confirmBuilder});
  @override
  ConsumerState<ContactsList> createState() => _ContactsListState();
}

class _ContactsListState extends ConsumerState<ContactsList> {
  bool _permissionDenied = false;
  List<Contact>? _contacts;
  List<Contact>? _filteredContacts;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future _fetchContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      setState(() => _permissionDenied = true);
    } else {
      final contacts = await FlutterContacts.getContacts(
          withThumbnail: true, withProperties: true);
      setState(() {
        _contacts =
            contacts.where((contact) => contact.phones.isNotEmpty).toList();
        _filteredContacts = _contacts!;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _contacts!
          .where((contact) =>
              contact.displayName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            autofocus: true,
            onChanged: _filterContacts,
            decoration: const InputDecoration(
              labelText: 'Search Contacts',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _permissionDenied
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Permission to read contacts was denied'))
              : _filteredContacts == null
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredContacts!.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No contacts found'))
                      : ListView.builder(
                          itemCount: _filteredContacts!.length,
                          prototypeItem: const ListTile(
                            title: Text('First Last'),
                          ),
                          itemBuilder: (context, index) {
                            Contact contact = _filteredContacts![index];
                            return ListTile(
                              onTap: () async {
                                final confirmed = widget.confirmBuilder == null
                                    ? true
                                    : await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) =>
                                            widget.confirmBuilder!(
                                                contact, <Widget>[
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: const Text('No'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: const Text('Yes'),
                                              ),
                                            ]));

                                if (confirmed != true) {
                                  return;
                                }

                                if (context.mounted) {
                                  Navigator.of(context)
                                      .pop(contact.phones.first.number);
                                }
                              },
                              leading: CircleAvatar(
                                backgroundImage:
                                    contact.photoOrThumbnail != null
                                        ? MemoryImage(contact.photoOrThumbnail!)
                                        : null,
                              ),
                              title: Text(contact.displayName),
                              subtitle: Text(
                                  formatPhone(contact.phones.first.number)),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
