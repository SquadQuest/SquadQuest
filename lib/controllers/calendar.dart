import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'package:squadquest/models/instance.dart';

abstract interface class CalendarController {
  static CalendarController? _instance;

  // Avoid self instance
  CalendarController._();
  factory CalendarController._getByPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _MobileCalendarController();
    }
    throw UnsupportedError(
        'CalendarController is not supported on this platform');
  }

  static CalendarController get instance =>
      _instance ??= CalendarController._getByPlatform();

  Future<bool> isAvailable();
  Future<bool> requestPermission();

  Future<void> upsertEvent({
    required InstanceMember subscription,
    required Instance instance,
  });
  Future<void> editEventRSVP();
  Future<void> findEvent();
}

class _MobileCalendarController implements CalendarController {
  static const defaultCalendarAccountName = "SquadQuest";
  static const defaultCalendarName = "SquadQuest Events";

  bool? get permissionGranted => _permissionGranted;

  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  bool? _permissionGranted;

  // As an example, our default timezone is UTC.
  Location _currentLocation = getLocation('UTC');

  _MobileCalendarController() {
    _checkCurrentLocation();
  }

  Future _checkCurrentLocation() async {
    String timezone = 'UTC';
    try {
      timezone = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      print('Could not get the local timezone');
    }
    _currentLocation = getLocation(timezone);
    tz.setLocalLocation(_currentLocation);
  }

  @override
  Future<bool> isAvailable() async {
    return (await _calendar.hasPermissions()).data ?? false;
  }

  @override
  Future<void> upsertEvent(
      {required InstanceMember subscription,
      required Instance instance}) async {
    _permissionGranted = await requestPermission();

    if (_permissionGranted != true) {
      return;
    }

    final calendarId = await _getCalendar();
    final existingEvent = await _getEventIdByInstance(calendarId, instance);

    final user = subscription.member;
    final event = instance;

    final startTime = event.startTimeMin;

    final result = await _calendar.createOrUpdateEvent(Event(
      calendarId,
      eventId: existingEvent,
      title: event.title,
      status: switch (event.status) {
        InstanceStatus.draft => null,
        InstanceStatus.live => EventStatus.Confirmed,
        InstanceStatus.canceled => EventStatus.Canceled,
      },
      description:
          "${event.notes}\n\nSquadQuest event: https://squadquest.app/event/${subscription.instanceId}",
      start: TZDateTime.from(startTime, _currentLocation),
      allDay: event.endTime == null,
      end: event.endTime != null
          ? TZDateTime.from(event.endTime!, _currentLocation)
          : TZDateTime(
              _currentLocation,
              startTime.year,
              startTime.month,
              startTime.day,
            ), // besides the nullality, this parameter is required
      location: event.locationDescription,
      reminders: [
        Reminder(minutes: 60),
      ],
      attendees: [
        Attendee(
          name: user!.fullName,
          // TODO(@themightychris): Email is mandatory. Do we have a standard email address?
          emailAddress:
              "${user.fullName.replaceAll(RegExp(r'[\W]'), '').toLowerCase()}"
              "@squadquest.app",
          role: AttendeeRole.None,
          androidAttendeeDetails: AndroidAttendeeDetails(
            attendanceStatus: switch (subscription.status) {
              // reversing to squadquest's enum:
              // None -> invited
              InstanceMemberStatus.invited => AndroidAttendanceStatus.Invited,
              InstanceMemberStatus.no => AndroidAttendanceStatus.Declined,
              InstanceMemberStatus.maybe => AndroidAttendanceStatus.Tentative,
              InstanceMemberStatus.yes ||
              InstanceMemberStatus.omw =>
                AndroidAttendanceStatus.Accepted,
            },
          ),
          iosAttendeeDetails: IosAttendeeDetails(
            attendanceStatus: switch (subscription.status) {
              // reversing to squadquest's enum:
              // Unknown -> Invited,
              // Delegated -> Maybe,
              // InProcess -> Yes,
              // Completed -> Yes,
              InstanceMemberStatus.invited => IosAttendanceStatus.Pending,
              InstanceMemberStatus.no => IosAttendanceStatus.Declined,
              InstanceMemberStatus.maybe => IosAttendanceStatus.Tentative,
              InstanceMemberStatus.yes => IosAttendanceStatus.Accepted,
              InstanceMemberStatus.omw => IosAttendanceStatus.InProcess,
            },
          ),
        ),
      ],
    ));

    if (result?.hasErrors == true) {
      logger.e(
          'CalendarController.upsertEvent: errors=\n${result?.errors.map((e) => e.errorMessage).join('\n')}');
      return;
    }

    _showEvent(result!.data);

    return;
  }

  @override
  Future<void> editEventRSVP() {
    throw UnimplementedError();
  }

  @override
  Future<void> findEvent() {
    throw UnimplementedError();
  }

  @override
  Future<bool> requestPermission() async {
    return (await _calendar.requestPermissions()).data ?? false;
  }

  Future<String?> _getEventIdByInstance(
      String calendarId, Instance instance) async {
    final event = await _calendar.retrieveEvents(
      calendarId,
      RetrieveEventsParams(
        startDate: instance.startTimeMin.subtract(const Duration(days: 1)),
        endDate: instance.endTime?.add(const Duration(days: 1)) ??
            instance.startTimeMin.add(const Duration(days: 60)),
      ),
    );

    if (event.hasErrors) {
      logger.e(
          'CalendarController._getEventIdByInstance: errors=\n${event.errors.map((e) => e.errorMessage).join('\n')}');
      return null;
    }

    if (event.data?.isNotEmpty != true) {
      return null;
    }

    return event.data
        ?.firstWhereOrNull(
          (element) => element.description?.contains(instance.id!) == true,
        )
        ?.eventId;
  }

  Future<String> _getCalendar() async {
    final calendars = await _calendar.retrieveCalendars();

    final foundCalendar = calendars.data?.firstWhereOrNull(
      (Calendar c) =>
          c.isReadOnly == false &&
          (c.name?.contains(defaultCalendarName) == true ||
              c.accountName?.contains(defaultCalendarAccountName) == true),
    );

    if (foundCalendar != null) {
      return foundCalendar.id!;
    } else {
      final newCalendar = await _calendar.createCalendar(
        defaultCalendarName,
        localAccountName: defaultCalendarAccountName,
        calendarColor: Colors.orange,
      );

      if (newCalendar.hasErrors) {
        throw newCalendar.errors.first.errorMessage;
      }
      return newCalendar.data!;
    }
  }

  void _showEvent(String? data) async {
    if (data == null) {
      return;
    }

    final event = await _calendar.retrieveEvents(
      await _getCalendar(),
      RetrieveEventsParams(eventIds: [data]),
    );

    if (event.hasErrors) {
      logger.e(
          'CalendarController._showEvent: errors=\n${event.errors.map((e) => e.errorMessage).join('\n')}');
      return;
    }

    if (event.data?.isNotEmpty == true) {
      final eventData = event.data!.first;
      logger.i(
        'CalendarController._showEvent: event=\n'
        'id=${eventData.eventId}\n'
        'calendarId=${eventData.calendarId}\n'
        'title=${eventData.title}\n'
        'description=${eventData.description}\n'
        'start=${eventData.start}\n'
        'end=${eventData.end}\n'
        'location=${eventData.location}\n'
        'attendees=${eventData.attendees}\n'
        'reminders=${eventData.reminders}\n'
        'status=${eventData.status}\n'
        'allDay=${eventData.allDay}\n',
      );
    }
  }
}
