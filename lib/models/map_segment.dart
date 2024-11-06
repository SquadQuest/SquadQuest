import 'dart:math';
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

  static List<MapSegment> _filterLargeGaps(
      List<MapSegment> segments, double threshold) {
    // Look for a segment that indicates a large gap
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Check if this segment represents a large gap:
      // - Has exactly 2 points (no intermediate points)
      // - Distance is greater than 5x the threshold
      if (segment.points.length == 2 && segment.distance > threshold * 5) {
        // Only keep segments newer than this gap
        return segments.sublist(0, i);
      }
    }

    return segments;
  }

  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  static List<MapSegment> _compressZigZaggingSegments(
      List<MapSegment> segments, double radiusThreshold) {
    if (segments.length < 3) return segments;

    final result = <MapSegment>[];
    int i = 0;

    while (i < segments.length) {
      // Try to find a cluster of segments that zig-zag around a point
      int clusterEnd = _findZigZagClusterEnd(segments, i, radiusThreshold);

      if (clusterEnd > i + 1) {
        // We found a cluster of zig-zagging segments
        // Create a new segment from the first point of the first segment
        // to the first point of the last segment (remember points are in reverse chronological order)
        result.add(MapSegment([
          segments[i].points.first,
          segments[clusterEnd].points.first,
        ]));
        i = clusterEnd + 1;
      } else {
        // No zig-zagging cluster found, keep the segment as is
        result.add(segments[i]);
        i++;
      }
    }

    return result;
  }

  static int _findZigZagClusterEnd(
      List<MapSegment> segments, int startIndex, double radiusThreshold) {
    if (startIndex >= segments.length - 2) return startIndex;

    // Calculate centroid of the first three segments
    var points = <LocationPoint>[];
    for (int i = startIndex; i < min(startIndex + 3, segments.length); i++) {
      points.addAll(segments[i].points);
    }

    double sumLat = 0;
    double sumLon = 0;
    for (var point in points) {
      sumLat += point.location.lat;
      sumLon += point.location.lon;
    }
    double centerLat = sumLat / points.length;
    double centerLon = sumLon / points.length;

    // Check how many consecutive segments have all points within the radius
    int endIndex = startIndex;
    for (int i = startIndex; i < segments.length; i++) {
      bool allPointsNearCenter = segments[i].points.every((point) {
        double distance = _haversineDistance(
          centerLat,
          centerLon,
          point.location.lat,
          point.location.lon,
        );
        return distance <= radiusThreshold;
      });

      if (!allPointsNearCenter) break;
      endIndex = i;
    }

    // Only consider it a cluster if we found at least 3 segments
    return endIndex >= startIndex + 2 ? endIndex : startIndex;
  }

  static subdivide(List<LocationPoint> points,
      {double threshold = 0.002,
      double? maxDistance,
      double zigzagRadius = 20}) {
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

    // Filter out segments behind any large gaps
    var filteredSegments = _filterLargeGaps(segments, threshold);

    // Compress any zig-zagging segments
    return _compressZigZaggingSegments(filteredSegments, zigzagRadius);
  }
}
