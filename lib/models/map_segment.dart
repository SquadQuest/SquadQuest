import 'package:geobase/geobase.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:squadquest/models/location_point.dart';

class MapSegment {
  final List<LocationPoint> points;

  // basic information
  int get length => points.length;
  DateTime get earliest => points.last.timestamp;
  int get earliestMilliseconds => earliest.millisecondsSinceEpoch;
  DateTime get latest => points.first.timestamp;
  int get latestMilliseconds => latest.millisecondsSinceEpoch;

  // geobase representations
  LineString? _lineString;
  LineString get lineString =>
      _lineString ??
      (_lineString =
          LineString.from(points.map((point) => point.location).toList()));
  Iterable<Position> get positions => lineString.chain.positions;

  // maplibre representations
  List<LatLng> get latLngList =>
      positions.map((position) => LatLng(position.y, position.x)).toList();

  // calculations
  double? _distance;
  double get distance => _distance ?? (_distance = lineString.length2D());

  int? _durationMilliseconds;
  int get durationMilliseconds =>
      _durationMilliseconds ??
      (_durationMilliseconds = latestMilliseconds - earliestMilliseconds);
  Duration? _duration;
  Duration get duration =>
      _duration ?? (_duration = Duration(milliseconds: durationMilliseconds));

  int? _midMilliseconds;
  int get midMilliseconds =>
      _midMilliseconds ?? (earliestMilliseconds + durationMilliseconds ~/ 2);
  DateTime? _midTimestamp;
  DateTime get midTimestamp =>
      _midTimestamp ??
      (_midTimestamp = DateTime.fromMillisecondsSinceEpoch(midMilliseconds));

  MapSegment(this.points)
      : assert(points.length >= 2, 'points must have at least 2 entries'),
        assert(points.first.timestamp.isAfter(points.last.timestamp),
            'points must be in reverse chronological order');

  static subdivide(List<LocationPoint> points,
      {double threshold = 200 / 111000, double? maxDistance}) {
    final segments = <MapSegment>[];
    int currentSegmentStart = 0;
    MapSegment? currentSegment;
    double distanceSum = 0;

    for (int i = currentSegmentStart + 1; i < points.length; i++) {
      // skip point if it is a duplicate of the last point
      if (i > 0 &&
          points[i].timestamp.isAtSameMomentAs(points[i - 1].timestamp)) {
        continue;
      }

      // draft current segment
      currentSegment = MapSegment(points.sublist(currentSegmentStart, i + 1));

      // complete segment if distance exceeds threshold
      if (currentSegment.distance > threshold) {
        segments.add(currentSegment);
        distanceSum += currentSegment.distance;

        currentSegment = null;
        currentSegmentStart = i;

        if (maxDistance != null && distanceSum > maxDistance) {
          break;
        } else {
          continue;
        }
      }
    }

    // add final segment
    if (currentSegment != null) {
      segments.add(currentSegment);
      distanceSum += currentSegment.distance;
    }

    return segments;
  }
}
