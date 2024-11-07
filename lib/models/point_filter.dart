import 'package:geobase/geobase.dart';
import 'dart:math';
import 'package:squadquest/models/location_point.dart';

class PointFilter {
  /// Filters out zigzag patterns in a list of points by replacing them with their centroids.
  /// Points must be in reverse chronological order (newest first).
  ///
  /// The [radiusThreshold] parameter determines how close points must be to be considered part of a zigzag pattern.
  /// The threshold is in coordinate units (typically degrees for geographic coordinates).
  static List<LocationPoint> filterZigZag(
      List<LocationPoint> points, double radiusThreshold) {
    if (points.length < 3) return points;

    final result = <LocationPoint>[];
    int i = 0;

    while (i < points.length - 1) {
      // Ensure there's always room for at least 2 points
      // Look ahead to find potential zigzag cluster
      int clusterEnd = i;
      Position? centroid;
      bool isZigZag = false;

      // First, try to detect a zigzag pattern using a small window (3-5 points)
      for (int j = i + 1; j < min(i + 5, points.length); j++) {
        var windowPoints =
            points.sublist(i, j + 1).map((p) => p.location).toList();

        var line = LineString.from(windowPoints);
        centroid = line.centroid2D();

        if (centroid != null) {
          // Check if all points in window are within radius of centroid
          bool allNearCenter = windowPoints.every((point) {
            var distanceLine = LineString.from([point, centroid!]);
            return distanceLine.length2D() <= radiusThreshold;
          });

          if (allNearCenter && windowPoints.length >= 3) {
            clusterEnd = j;
            isZigZag = true;

            // Once we've found a zigzag pattern, try to extend it
            // Continue checking subsequent points as long as they stay within radius
            for (int k = j + 1; k < points.length; k++) {
              var point = points[k].location;
              var distanceLine = LineString.from([point, centroid]);
              if (distanceLine.length2D() <= radiusThreshold) {
                clusterEnd = k;
              } else {
                break;
              }
            }
            break;
          }
        }
      }

      if (isZigZag && centroid != null) {
        // Create a new point at the centroid, using metadata from the newest point
        var clusterPoints = points.sublist(i, clusterEnd + 1);
        var avgTime = clusterPoints.fold<int>(0,
                (sum, point) => sum + point.timestamp.millisecondsSinceEpoch) ~/
            clusterPoints.length;

        // Use the newest point (first in cluster) as template for metadata
        var templatePoint = clusterPoints.first;
        result.add(LocationPoint(
          id: '${templatePoint.id}_centroid',
          createdAt: DateTime.now(),
          createdBy: templatePoint.createdBy,
          event: templatePoint.event,
          timestamp: DateTime.fromMillisecondsSinceEpoch(avgTime),
          location: Geographic(lon: centroid.x, lat: centroid.y),
        ));
        i = clusterEnd + 1;
      } else {
        result.add(points[i]);
        i++;
      }
    }

    // Add the last point if we haven't processed it as part of a zigzag cluster
    if (i < points.length) {
      result.add(points[i]);
    }

    return result;
  }
}
