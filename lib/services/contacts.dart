import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'package:squadquest/services/router.dart';
import 'package:squadquest/services/preferences.dart';

export 'package:flutter_contacts/flutter_contacts.dart' show Contact;

final contactsProvider =
    AsyncNotifierProvider<ContactsService, List<Contact>>(ContactsService.new);

class ContactsService extends AsyncNotifier<List<Contact>> {
  bool? get permissionGranted => _permissionGranted;

  bool? _permissionGranted;

  @override
  Future<List<Contact>> build() async {
    if (_permissionGranted != true) {
      return [];
    }

    return FlutterContacts.getContacts(
        withThumbnail: true, withProperties: true);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<bool?> requestPermission() async {
    if (_permissionGranted == true) {
      return true;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final confirmedContactsPermission =
        prefs.getBool('confirmedContactsPermission');

    final confirmed = confirmedContactsPermission == true ||
        true ==
            await showDialog<bool>(
                context: navigatorKey.currentContext!,
                builder: (BuildContext context) => AlertDialog(
                      title: const Text('Permission to access contacts'),
                      content: const Text(
                          'SquadQuest is about to request access to your contacts so you can search'
                          ' and select people to send friend requests to. Your contacts\' details'
                          ' outside any you confirm you want to send a friend request too will'
                          ' never be sent to any server or stored in any way after the app closes.'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Nevermind'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sounds good'),
                        ),
                      ],
                    ));

    if (confirmed != true) {
      return null;
    }

    await prefs.setBool('confirmedContactsPermission', true);

    _permissionGranted =
        await FlutterContacts.requestPermission(readonly: true);

    if (_permissionGranted == true) {
      refresh();
    }

    return _permissionGranted!;
  }
}
