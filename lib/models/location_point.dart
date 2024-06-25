import 'package:geobase/coordinates.dart';

import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/user.dart';

typedef LocationPointID = String;

class LocationPoint {
  final LocationPointID id;
  final DateTime createdAt;
  final UserID createdBy;
  final InstanceID event;
  final DateTime timestamp;
  final Geographic location;

  LocationPoint({
    required this.id,
    required this.createdAt,
    required this.createdBy,
    required this.event,
    required this.timestamp,
    required this.location,
  });

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    final [longitude, latitude] = map['location_text']
        .substring(6, map['location_text'].length - 1)
        .split(' ');

    return LocationPoint(
        id: map['id'] as LocationPointID,
        createdAt: DateTime.parse(map['created_at']).toLocal(),
        createdBy: map['created_by'] as UserID,
        event: map['event'] as InstanceID,
        timestamp: DateTime.parse(map['timestamp']).toLocal(),
        location: Geographic(
            lon: double.parse(longitude), lat: double.parse(latitude)));
  }

  @override
  String toString() {
    return 'LocationPoint{id: $id, event: $event, timestamp: $timestamp}';
  }
}
