import 'dart:io';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

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

Future<Uri> uploadPhoto(
    Uri photo, String path, SupabaseClient supabase, String bucketName,
    {TransformOptions? transform}) async {
  // already-online URI need to further processing
  if (photo.isScheme('http') || photo.isScheme('https')) {
    return photo;
  }

  if (photo.isScheme('file')) {
    await supabase.storage.from(bucketName).upload(
        path, File(photo.toFilePath()),
        fileOptions: const FileOptions(upsert: true));
  } else if (photo.isScheme('blob')) {
    final response = await http.get(photo);
    await supabase.storage.from(bucketName).uploadBinary(
        path, response.bodyBytes,
        fileOptions: FileOptions(
            upsert: true, contentType: response.headers['content-type']));
  } else {
    throw UnimplementedError('Unsupported photo URI: $photo');
  }

  final photoUrl = supabase.storage.from(bucketName).getPublicUrl(
        path,
        transform: transform,
      );

  // append cache buster to force refresh of new upload
  return Uri.parse('$photoUrl&v=${DateTime.now().millisecondsSinceEpoch}');
}

Future<Uri> movePhoto(
    String from, String to, SupabaseClient supabase, String bucketName,
    {TransformOptions? transform, bool upsert = false}) async {
  // delete any existing destination photo first
  if (upsert) {
    await supabase.storage.from(bucketName).remove([to]);
  }

  // move photo
  await supabase.storage.from(bucketName).move(from, to);

  final photoUrl = supabase.storage.from(bucketName).getPublicUrl(
        to,
        transform: transform,
      );

  // append cache buster to force refresh of new upload
  return Uri.parse('$photoUrl&v=${DateTime.now().millisecondsSinceEpoch}');
}

extension IterableExtensions<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) comparator) {
    try {
      return firstWhere(comparator);
    } on StateError catch (_) {
      return null;
    }
  }
}
