import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

export 'package:flutter_contacts/flutter_contacts.dart' show Contact;

final contactsProvider =
    AsyncNotifierProvider<ContactsService, List<Contact>>(ContactsService.new);

class ContactsService extends AsyncNotifier<List<Contact>> {
  bool get permissionDenied => _permissionDenied;

  bool _permissionDenied = false;

  @override
  Future<List<Contact>> build() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      _permissionDenied = true;
      return [];
    }

    return FlutterContacts.getContacts(
        withThumbnail: true, withProperties: true);
  }
}
