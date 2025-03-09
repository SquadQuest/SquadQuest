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
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return _CalendarController();
    }
    throw UnsupportedError(
        'CalendarController is not supported on this platform');
  }

  static CalendarController get instance =>
      _instance ??= CalendarController._getByPlatform();

  /// Returns true if enough time has passed since the last sync to perform another sync.
  bool canSync();

  /// Performs a full sync of all events in the calendar with the app's data.
  /// This ensures that all events in the calendar match the user's RSVPs.
  Future<void> performFullSync({
    required List<Instance> instances,
    required List<InstanceMember> rsvps,
  });

  /// Returns true if the device has permission to access the calendar.
  Future<bool> isAvailable();

  /// Requests permission to access the calendar.
  Future<bool> requestPermission();

  /// Creates or updates an event in the device's calendar based on the provided
  /// instance and subscription. The event will have in its description a link to
  /// the instance's page on squadquest app.
  Future<void> upsertEvent({
    required Instance instance,
    required InstanceMember? subscription,
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

class _CalendarController implements CalendarController {
  static const Duration syncCooldown = Duration(minutes: 5);
  static const defaultCalendarAccountName = "SquadQuest";
  static const defaultCalendarName = "SquadQuest Events";

  bool? get permissionGranted => _permissionGranted;

  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  bool? _permissionGranted;
  String _currentTimezone = 'UTC';
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  _CalendarController() {
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
  bool canSync() {
    return _lastSyncTime == null ||
        DateTime.now().difference(_lastSyncTime!) > syncCooldown;
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
  Future<void> performFullSync({
    required List<Instance> instances,
    required List<InstanceMember> rsvps,
  }) async {
    logger.d('Starting full calendar sync');

    // Prevent concurrent syncs
    if (_isSyncing) {
      logger.d('Sync already in progress, skipping');
      return;
    }

    try {
      _isSyncing = true;
      _lastSyncTime = DateTime.now();

      // Check permissions first
      _permissionGranted = await requestPermission();
      if (_permissionGranted != true) {
        logger.d('Calendar permission not granted, skipping sync');
        return;
      }

      if (instances.isEmpty || rsvps.isEmpty) {
        logger.d('No events or RSVPs to sync');
        return;
      }

      // Calculate the cutoff time for events (1 week ago)
      final maxStartTime = _lastSyncTime!.subtract(const Duration(days: 7));

      // Create a map of instance ID to instance for quick lookup
      final instanceMap = {
        for (var instance in instances) instance.id!: instance
      };

      // Process each RSVP
      int rsvpsProcessed = 0;
      for (final rsvp in rsvps) {
        // Skip if we don't have the instance
        final instance = instanceMap[rsvp.instanceId];
        if (instance == null) continue;

        try {
          // Skip events that started more than a week ago
          if (instance.startTimeMin.isBefore(maxStartTime)) {
            continue;
          }

          rsvpsProcessed++;

          // Skip events the user has declined
          if (rsvp.status == InstanceMemberStatus.no) {
            await _performCalendarOperation(_CalendarOperation(
              instance: instance,
              isDelete: true,
              timezone: _currentTimezone,
              calendar: _calendar,
            ));
            continue;
          }

          // Skip canceled events
          if (instance.status == InstanceStatus.canceled) {
            await _performCalendarOperation(_CalendarOperation(
              instance: instance,
              isDelete: true,
              timezone: _currentTimezone,
              calendar: _calendar,
            ));
            continue;
          }

          // Create or update the calendar event
          await _performCalendarOperation(_CalendarOperation(
            instance: instance,
            subscription: rsvp,
            isDelete: false,
            timezone: _currentTimezone,
            calendar: _calendar,
          ));
        } catch (e) {
          logger.e('Error syncing event ${instance.id}', error: e);
          // Continue with other events even if one fails
        }
      }

      logger.d('Calendar sync completed, $rsvpsProcessed RSVPs processed');
    } catch (e, stack) {
      logger.e('Calendar sync failed', error: e, stackTrace: stack);
    } finally {
      _isSyncing = false;
    }
  }

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
          title: switch (op.subscription!.status) {
            InstanceMemberStatus.maybe => '[maybe] ${event.title}',
            InstanceMemberStatus.invited => '[invited] ${event.title}',
            _ => event.title,
          },
          location: event.locationDescription,
          description:
              "${event.notes}\n\nSquadQuest event: https://squadquest.app/events/${event.id!}",
          start: TZDateTime.from(event.startTimeMin, location),
          end: TZDateTime.from(event.endTime ?? event.startTimeMax, location),
          reminders: [
            Reminder(minutes: 60),
          ],
          availability: switch (op.subscription!.status) {
            InstanceMemberStatus.omw => Availability.Busy,
            InstanceMemberStatus.yes => Availability.Busy,
            InstanceMemberStatus.maybe => Availability.Free,
            InstanceMemberStatus.no => Availability.Free,
            InstanceMemberStatus.invited => Availability.Free,
          },
          status: switch (event.status) {
            InstanceStatus.draft => EventStatus.Tentative,
            InstanceStatus.canceled => EventStatus.Canceled,
            InstanceStatus.live
                when (op.subscription!.status == InstanceMemberStatus.omw) =>
              EventStatus.Confirmed,
            InstanceStatus.live
                when (op.subscription!.status == InstanceMemberStatus.yes) =>
              EventStatus.Confirmed,
            InstanceStatus.live
                when (op.subscription!.status == InstanceMemberStatus.maybe) =>
              EventStatus.Confirmed,
            InstanceStatus.live
                when (op.subscription!.status ==
                    InstanceMemberStatus.invited) =>
              EventStatus.Confirmed,
            _ => EventStatus.None,
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
      rethrow;
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
