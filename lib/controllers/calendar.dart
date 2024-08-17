import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:squadquest/common.dart';
import 'package:squadquest/logger.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

/// {@template calendar_controller}
///
/// A controller for interacting with the device's calendar. This is used to create
/// and update events in the device's calendar.
///
/// {@endtemplate}
abstract interface class CalendarController {
  static CalendarController? _instance;

  // Avoid self instance
  CalendarController._();
  factory CalendarController._getByPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _MobileCalendarController();
    }
    throw UnsupportedError('CalendarController is not supported on this platform');
  }

  static CalendarController get instance => _instance ??= CalendarController._getByPlatform();

  /// Returns true if the device has permission to access the calendar.
  Future<bool> isAvailable();

  /// Requests permission to access the calendar.
  Future<bool> requestPermission();

  /// Creates or updates an event in the device's calendar based on the provided
  /// instance and subscription. The event will have in its description a link to
  /// the instance's page on squadquest app.
  Future<void> upsertEvent({
    required InstanceMember subscription,
    required Instance instance,
  });

  /// Deletes an event from the device's calendar based on the provided instance.
  Future<void> deleteEvent(Instance instance);
}

/// {@macro calendar_controller}
class _MobileCalendarController implements CalendarController {
  static const defaultCalendarAccountName = "SquadQuest";
  static const defaultCalendarName = "SquadQuest Events";

  bool? get permissionGranted => _permissionGranted;

  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  bool? _permissionGranted;

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
  Future<bool> requestPermission() async {
    return (await _calendar.requestPermissions()).data ?? false;
  }

  @override
  Future<void> upsertEvent({
    required Instance instance,
    required InstanceMember? subscription,
  }) async {
    logger.d('CalendarController.upsertEvent');
    _permissionGranted = await requestPermission();

    if (_permissionGranted != true) {
      logger.d('CalendarController.upsertEvent -> permission not granted');
      return;
    }

    final calendarId = await _getCalendar();
    final existingEvent = await _getEventIdByInstance(calendarId, instance);

    final user = subscription?.member;
    final event = instance;
    final eventCreatorId = (instance.createdBy?.id ?? instance.createdById);

    final result = await _calendar.createOrUpdateEvent(Event(
      calendarId,
      eventId: existingEvent,
      title: event.title,
      location: event.locationDescription,
      description:
          "${event.notes}\n\nSquadQuest event: https://squadquest.app/event/${instance.id!}",
      start: TZDateTime.from(event.startTimeMin, _currentLocation),
      // endTime is a fuzzy concept right now that only gets set sometimes after an event is over
      // -- in the future we may enable setting it ahead of time while creating an event
      // allDay: event.endTime == null,
      // end: event.endTime != null
      //     ? TZDateTime.from(event.endTime!, _currentLocation)
      //     : TZDateTime(
      //         _currentLocation,
      //         startTime.year,
      //         startTime.month,
      //         startTime.day,
      //       ), // besides the nullality, this parameter is required
      // for now, use the startTimeMax as the end—this indicates the range of time for "showing up"
      end: TZDateTime.from(event.startTimeMax, _currentLocation),
      reminders: [
        Reminder(minutes: 60),
      ],
      status: switch (event.status) {
        InstanceStatus.draft => null,
        InstanceStatus.live => EventStatus.Confirmed,
        InstanceStatus.canceled => EventStatus.Canceled,
      },
      attendees: [
        if (subscription != null && user != null)
          _UserAttendee.fromUser(
            user,
            eventCreatorId == user.id,
            subscription.status,
          )
      ],
    ));

    if (result?.hasErrors == true) {
      logger.e(
          'CalendarController.upsertEvent: errors=\n${result?.errors.map((e) => e.errorMessage).join('\n')}');
      return;
    }

    _showEvent(result!.data);

    logger.d('CalendarController.upsertEvent -> finished');
    return;
  }

  @override
  Future<void> deleteEvent(Instance instance) async {
    logger.d('CalendarController.deleteEvent');

    _permissionGranted = await requestPermission();
    if (_permissionGranted != true) {
      logger.d('CalendarController.deleteEvent -> permission not granted');
      return;
    }

    final calendarId = await _getCalendar();

    final existingEventId = await _getEventIdByInstance(calendarId, instance);

    if (existingEventId == null) {
      logger.d('CalendarController.deleteEvent -> no event found');
      return;
    }

    final result = await _calendar.deleteEvent(calendarId, existingEventId);

    if (result.hasErrors == true) {
      logger.e(
          'CalendarController.deleteEvent: errors=\n${result.errors.map((e) => e.errorMessage).join('\n')}');
      return;
    }

    logger.d('CalendarController.deleteEvent -> finished');
    return;
  }

  /// Returns the eventId of the event that matches the instance or null if no match
  /// is found.
  Future<String?> _getEventIdByInstance(String calendarId, Instance instance) async {
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

  /// Returns the calendarId for creating or updating an event. If no calendar
  /// exists, a new one is created.
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
        'attendees=${eventData.attendees?.map(
              (e) => "\n"
                  "\tname=${e?.name}\n"
                  "\temailAddress=${e?.emailAddress}\n"
                  "\trole=${e?.role}\n"
                  "\tisCurrentUser=${e?.isCurrentUser}\n"
                  "\tisOrganiser=${e?.isOrganiser}\n"
                  "\tandroidAttendeeDetails=${e?.androidAttendeeDetails?.attendanceStatus?.enumToString}\n"
                  "\tiosAttendeeDetails=${e?.iosAttendeeDetails?.attendanceStatus?.enumToString}\n",
            ).join('\n')}\n'
        'reminders=${eventData.reminders}\n'
        'status=${eventData.status}\n'
        'allDay=${eventData.allDay}\n',
      );
    }
  }
}

extension _UserAttendee on Attendee {
  static Attendee fromUser(
    UserProfile user,
    bool isOrganizer,
    InstanceMemberStatus? rsvpStatus,
  ) {
    return Attendee(
      isCurrentUser: true,
      isOrganiser: isOrganizer,
      name: user.fullName,
      emailAddress: "calendars@squadquest.app",
      role: AttendeeRole.None,
      androidAttendeeDetails: AndroidAttendeeDetails(
        attendanceStatus: switch (rsvpStatus) {
          // reversing to squadquest's enum:
          // None -> invited
          null => AndroidAttendanceStatus.None,
          InstanceMemberStatus.invited => AndroidAttendanceStatus.Invited,
          InstanceMemberStatus.no => AndroidAttendanceStatus.Declined,
          InstanceMemberStatus.maybe => AndroidAttendanceStatus.Tentative,
          InstanceMemberStatus.yes || InstanceMemberStatus.omw => AndroidAttendanceStatus.Accepted,
        },
      ),
      iosAttendeeDetails: IosAttendeeDetails(
        attendanceStatus: switch (rsvpStatus) {
          // reversing to squadquest's enum:
          // Unknown -> Invited,
          // Delegated -> Maybe,
          // InProcess -> Yes,
          // Completed -> Yes,
          null => IosAttendanceStatus.Unknown,
          InstanceMemberStatus.invited => IosAttendanceStatus.Pending,
          InstanceMemberStatus.no => IosAttendanceStatus.Declined,
          InstanceMemberStatus.maybe => IosAttendanceStatus.Tentative,
          InstanceMemberStatus.yes => IosAttendanceStatus.Accepted,
          InstanceMemberStatus.omw => IosAttendanceStatus.InProcess,
        },
      ),
    );
  }
}
