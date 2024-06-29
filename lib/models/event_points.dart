import 'package:geobase/coordinates.dart';

import 'package:squadquest/models/instance.dart';

class EventPoints {
  final InstanceID id;
  final DateTime? latest;
  final int users;
  final List<Geographic> userPoints;

  EventPoints(
      {required this.id,
      required this.latest,
      required this.users,
      required this.userPoints});

  factory EventPoints.fromMap(Map<String, dynamic> map) {
    final userPointsText =
        map['user_points'] == null ? [] : map['user_points'].split(';');

    final userPoints = userPointsText
        .map((pointText) {
          final [longitude, latitude] =
              pointText.substring(6, pointText.length - 1).split(' ');
          return Geographic(
              lon: double.parse(longitude), lat: double.parse(latitude));
        })
        .toList()
        .cast<Geographic>();

    return EventPoints(
        id: map['id'],
        latest: map['latest'] == null
            ? null
            : DateTime.parse(map['latest']).toLocal(),
        users: map['users'],
        userPoints: userPoints);
  }

  @override
  String toString() {
    return 'EventPoints{id: $id, users: $users}';
  }
}
