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

final phoneInputFilter =
    FilteringTextInputFormatter.deny(RegExp(r'[^+\(\) 0-9\-]'));
