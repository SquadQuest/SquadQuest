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
    throw UnsupportedError(
        'CalendarController is not supported on this platform');
  }

  static CalendarController get instance =>
      _instance ??= CalendarController._getByPlatform();

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

/// Data needed for calendar operations
class _CalendarOperation {
  final Instance instance;
  final InstanceMember? subscription;
  final bool isDelete;
  final String timezone;
  final DeviceCalendarPlugin calendar;

  _CalendarOperation({
    required this.instance,
    this.subscription,
    required this.isDelete,
    required this.timezone,
    required this.calendar,
  });
}

/// {@macro calendar_controller}
class _MobileCalendarController implements CalendarController {
  static const defaultCalendarAccountName = "SquadQuest";
  static const defaultCalendarName = "SquadQuest Events";

  bool? get permissionGranted => _permissionGranted;

  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  bool? _permissionGranted;
  String _currentTimezone = 'UTC';

  _MobileCalendarController() {
    _initializeTimezone();
  }

  Future<void> _initializeTimezone() async {
    try {
      _currentTimezone = await FlutterTimezone.getLocalTimezone();
    } catch (error, stackTrace) {
      logger.e('Could not get the local timezone',
          error: error, stackTrace: stackTrace);
    }
    final location = getLocation(_currentTimezone);
    tz.setLocalLocation(location);
  }

  @override
  Future<bool> isAvailable() async {
    return (await _calendar.hasPermissions()).data ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    return (await _calendar.requestPermissions()).data ?? false;
  }

  /// Handles calendar operations in a separate isolate to prevent UI blocking
  Future<void> _performCalendarOperation(_CalendarOperation op) async {
    final location = getLocation(op.timezone);

    try {
      // Get or create calendar
      final calendars = await op.calendar.retrieveCalendars();
      String? calendarId;

      final foundCalendar = calendars.data?.firstWhereOrNull(
        (Calendar c) =>
            c.isReadOnly == false &&
            (c.name?.contains(defaultCalendarName) == true ||
                c.accountName?.contains(defaultCalendarAccountName) == true),
      );

      if (foundCalendar != null) {
        calendarId = foundCalendar.id!;
      } else {
        final newCalendar = await op.calendar.createCalendar(
          defaultCalendarName,
          localAccountName: defaultCalendarAccountName,
          calendarColor: Colors.orange,
        );

        if (!newCalendar.hasErrors) {
          calendarId = newCalendar.data!;
        }
      }

      if (calendarId == null) return;

      if (op.isDelete) {
        // Handle deletion
        final existingEvent = await _findExistingEvent(
            op.calendar, calendarId, op.instance, location);
        if (existingEvent != null) {
          await op.calendar.deleteEvent(calendarId, existingEvent);
        }
      } else {
        // Handle creation/update
        final existingEventId = await _findExistingEvent(
            op.calendar, calendarId, op.instance, location);

        final user = op.subscription?.member;
        final event = op.instance;
        final eventCreatorId = (event.createdBy?.id ?? event.createdById);

        await op.calendar.createOrUpdateEvent(Event(
          calendarId,
          eventId: existingEventId,
          title: event.title,
          location: event.locationDescription,
          description:
              "${event.notes}\n\nSquadQuest event: https://squadquest.app/events/${event.id!}",
          start: TZDateTime.from(event.startTimeMin, location),
          end: TZDateTime.from(event.startTimeMax, location),
          reminders: [
            Reminder(minutes: 60),
          ],
          status: switch (event.status) {
            InstanceStatus.draft => null,
            InstanceStatus.live => EventStatus.Confirmed,
            InstanceStatus.canceled => EventStatus.Canceled,
          },
          attendees: [
            if (op.subscription != null && user != null)
              _UserAttendee.fromUser(
                user,
                eventCreatorId == user.id,
                op.subscription!.status,
              )
          ],
        ));
      }
    } catch (e, stack) {
      logger.e('Calendar operation failed', error: e, stackTrace: stack);
      rethrow; // Ensure the error is propagated
    }
  }

  static Future<String?> _findExistingEvent(DeviceCalendarPlugin calendar,
      String calendarId, Instance instance, Location location) async {
    final events = await calendar.retrieveEvents(
      calendarId,
      RetrieveEventsParams(
        startDate: instance.startTimeMin.subtract(const Duration(days: 1)),
        endDate: instance.endTime?.add(const Duration(days: 1)) ??
            instance.startTimeMin.add(const Duration(days: 60)),
      ),
    );

    if (events.hasErrors || events.data?.isEmpty == true) {
      return null;
    }

    return events.data
        ?.firstWhereOrNull(
          (element) => element.description?.contains(instance.id!) == true,
        )
        ?.eventId;
  }

  @override
  Future<void> upsertEvent({
    required Instance instance,
    required InstanceMember? subscription,
  }) async {
    logger.d('CalendarController.upsertEvent');

    // Check permissions in the main isolate first
    _permissionGranted = await requestPermission();
    if (_permissionGranted != true) {
      logger.d('CalendarController.upsertEvent -> permission not granted');
      return;
    }

    try {
      // Run the calendar operation
      await _performCalendarOperation(_CalendarOperation(
        instance: instance,
        subscription: subscription,
        isDelete: false,
        timezone: _currentTimezone,
        calendar: _calendar,
      ));

      logger.d('CalendarController.upsertEvent -> finished');
    } catch (e, stack) {
      logger.e('CalendarController.upsertEvent failed',
          error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteEvent(Instance instance) async {
    logger.d('CalendarController.deleteEvent');

    _permissionGranted = await requestPermission();
    if (_permissionGranted != true) {
      logger.d('CalendarController.deleteEvent -> permission not granted');
      return;
    }

    try {
      // Run the deletion
      await _performCalendarOperation(_CalendarOperation(
        instance: instance,
        isDelete: true,
        timezone: _currentTimezone,
        calendar: _calendar,
      ));

      logger.d('CalendarController.deleteEvent -> finished');
    } catch (e, stack) {
      logger.e('CalendarController.deleteEvent failed',
          error: e, stackTrace: stack);
      rethrow;
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
          InstanceMemberStatus.yes ||
          InstanceMemberStatus.omw =>
            AndroidAttendanceStatus.Accepted,
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
