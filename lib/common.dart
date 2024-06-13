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
