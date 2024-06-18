import 'package:flutter/services.dart';

String normalizePhone(String phone) {
  // Remove non-digits
  phone = phone.replaceAll(RegExp(r'[^\d]'), '');

  // Ensure leading 1
  if (phone[0] != '1') {
    phone = '1$phone';
  }

  return phone;
}

String formatPhone(String phone) {
  final normalized = normalizePhone(phone);

  if (normalized.length == 11) {
    return '(${normalized.substring(1, 4)}) ${normalized.substring(4, 7)}-${normalized.substring(7)}';
  } else {
    return normalized;
  }
}

final phoneInputFilter =
    FilteringTextInputFormatter.deny(RegExp(r'[^+\(\) 0-9\-]'));

List<T> updateListWithRecord<T>(
    List<T> list, bool Function(T) where, T? record) {
  late List<T> updatedList;
  final currentIndex = list.indexWhere(where);

  if (currentIndex == -1) {
    if (record == null) {
      // no-op
      updatedList = list;
    } else {
      // append a new record
      updatedList = [
        ...list,
        record,
      ];
    }
  } else if (record == null) {
    // remove existing record
    updatedList = [
      ...list.sublist(0, currentIndex),
      ...list.sublist(currentIndex + 1)
    ];
  } else {
    // replace existing record
    updatedList = [
      ...list.sublist(0, currentIndex),
      record,
      ...list.sublist(currentIndex + 1)
    ];
  }

  return updatedList;
}
