import 'package:geobase/geobase.dart';
import 'dart:math';
import 'package:squadquest/models/location_point.dart';

class PointFilter {
  /// Filters location points by:
  /// 1. Detecting and compressing zigzag patterns into centroids
  /// 2. Detecting large gaps in tracking and truncating points after the gap
  ///
  /// Points must be in reverse chronological order (newest first).
  ///
  /// Parameters:
  /// - [points]: The points to filter, in reverse chronological order
  /// - [zigzagRadius]: How close points must be to be considered part of a zigzag pattern
  /// - [largeGapThreshold]: Distance threshold that triggers truncation when exceeded
  /// - [enableZigzagFilter]: Whether to detect and compress zigzag patterns
  /// - [enableGapFilter]: Whether to detect and truncate at large gaps
  static List<LocationPoint> filter(
    List<LocationPoint> points, {
    required double zigzagRadius,
    required double largeGapThreshold,
    bool enableZigzagFilter = true,
    bool enableGapFilter = true,
  }) {
    if (points.length < 2) return points;

    final result = <LocationPoint>[];

    // Always include the newest point
    result.add(points.first);

    int i = 1; // Start from second point since we've added the first

    while (i < points.length - 1) {
      // Look for zigzag patterns if enabled
      if (enableZigzagFilter) {
        int clusterEnd = i;
        Position? centroid;
        bool isZigZag = false;

        // Try to detect a zigzag pattern using a small window (3-5 points)
        for (int j = i + 1; j < min(i + 5, points.length); j++) {
          var windowPoints =
              points.sublist(i, j + 1).map((p) => p.location).toList();

          var line = LineString.from(windowPoints);
          centroid = line.centroid2D();

          if (centroid != null) {
            // Check if all points in window are within radius of centroid
            bool allNearCenter = windowPoints.every((point) {
              var distanceLine = LineString.from([point, centroid!]);
              return distanceLine.length2D() <= zigzagRadius;
            });

            if (allNearCenter && windowPoints.length >= 3) {
              clusterEnd = j;
              isZigZag = true;

              // Once we've found a zigzag pattern, try to extend it
              // Continue checking subsequent points as long as they stay within radius
              // A point outside the radius will naturally break the cluster,
              // whether it's a large gap or just the end of the zigzag pattern
              for (int k = j + 1; k < points.length; k++) {
                var point = points[k].location;
                var distanceLine = LineString.from([point, centroid]);
                if (distanceLine.length2D() <= zigzagRadius) {
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
          // Create a new point at the centroid, using metadata from the first point in cluster
          var clusterPoints = points.sublist(i, clusterEnd + 1);

          // Use the first point in cluster as template for metadata
          var templatePoint = clusterPoints.first;
          var centroidPoint = LocationPoint(
            id: '${templatePoint.id}_centroid',
            createdAt: DateTime.now(),
            createdBy: templatePoint.createdBy,
            event: templatePoint.event,
            timestamp: templatePoint.timestamp,
            location: Geographic(lon: centroid.x, lat: centroid.y),
          );

          // Check for large gap between centroid and next point after cluster
          if (enableGapFilter && clusterEnd + 1 < points.length) {
            var nextPoint = points[clusterEnd + 1];
            var gapLine =
                LineString.from([centroidPoint.location, nextPoint.location]);
            if (gapLine.length2D() > largeGapThreshold) {
              // Found a large gap - add the centroid point and stop processing
              result.add(centroidPoint);
              break;
            }
          }

          result.add(centroidPoint);
          i = clusterEnd + 1;
          continue;
        }
      }

      // Check for large gaps between consecutive points
      if (enableGapFilter) {
        var currentPoint = points[i];
        var nextPoint = points[i + 1];

        // Create a LineString to measure distance between points
        var line = LineString.from([currentPoint.location, nextPoint.location]);
        if (line.length2D() > largeGapThreshold) {
          // Found a large gap - keep the current point and stop processing
          result.add(currentPoint);
          break;
        }
      }

      // If no zigzag pattern was found, add the current point and move on
      result.add(points[i]);
      i++;
    }

    // Add the last point if we haven't processed it as part of a zigzag cluster
    // and haven't stopped due to a large gap
    if (i < points.length) {
      result.add(points[i]);
    }

    return result;
  }
}
