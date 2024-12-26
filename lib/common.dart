import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';

String normalizePhone(String phone) {
  PhoneNumber number = PhoneNumberUtil.instance.parse(phone, 'US');
  return PhoneNumberUtil.instance.format(number, PhoneNumberFormat.e164);
}

String formatPhone(String phone) {
  try {
    PhoneNumber number = PhoneNumberUtil.instance.parse(phone, 'US');
    return PhoneNumberUtil.instance.format(number, PhoneNumberFormat.national);
  } catch (error) {
    return phone;
  }
}

List<T> updateListWithRecord<T>(List<T> list, bool Function(T) where, T? record,
    {bool prepend = false}) {
  late List<T> updatedList;
  final currentIndex = list.indexWhere(where);

  if (currentIndex == -1) {
    if (record == null) {
      // no-op
      updatedList = list;
    } else {
      // append a new record
      updatedList = prepend
          ? [
              record,
              ...list,
            ]
          : [
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

TimeOfDay addMinutesToTimeOfDay(TimeOfDay timeOfDay, int minutes) {
  if (minutes == 0) {
    return timeOfDay;
  } else {
    int mofd = timeOfDay.hour * 60 + timeOfDay.minute;
    int newMofd = ((minutes % 1440) + mofd + 1440) % 1440;
    if (mofd == newMofd) {
      return timeOfDay;
    } else {
      int newHour = newMofd ~/ 60;
      int newMinute = newMofd % 60;
      return TimeOfDay(hour: newHour, minute: newMinute);
    }
  }
}

String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);

  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
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
