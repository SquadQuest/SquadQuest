import 'package:geobase/geobase.dart';
import 'dart:math';
import 'package:squadquest/models/location_point.dart';

class PointFilter {
  /// Analyzes a sequence of points to detect zigzag patterns
  /// Returns the number of direction changes found
  static int _analyzePattern(
      List<Geographic> points, double minDeltaThreshold) {
    if (points.length < 3) return 0;

    var directionChanges = 0;
    var lastDirection = _getDirection(points[0], points[1]);

    for (int i = 1; i < points.length - 1; i++) {
      var currentDirection = _getDirection(points[i], points[i + 1]);

      // Skip tiny movements
      if (currentDirection.lon.abs() < minDeltaThreshold &&
          currentDirection.lat.abs() < minDeltaThreshold) {
        continue;
      }

      // Check for direction change in either longitude or latitude
      if ((lastDirection.lon * currentDirection.lon < 0) ||
          (lastDirection.lat * currentDirection.lat < 0)) {
        directionChanges++;
      }

      lastDirection = currentDirection;
    }

    return directionChanges;
  }

  /// Gets the direction vector between two points
  static _Direction _getDirection(Geographic p1, Geographic p2) {
    return _Direction(
      lon: p2.lon - p1.lon,
      lat: p2.lat - p1.lat,
    );
  }

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
    final minDeltaThreshold =
        zigzagRadius * 0.1; // 10% of radius as minimum change

    // Always include the newest point
    result.add(points.first);

    int i = 1; // Start from second point since we've added the first

    while (i < points.length - 1) {
      // Look for zigzag patterns if enabled
      if (enableZigzagFilter) {
        int clusterEnd = i;
        Position? centroid;
        bool isZigZag = false;

        // Use a larger window to detect patterns
        for (int windowSize = 5;
            windowSize <= 10 && i + windowSize < points.length;
            windowSize++) {
          var windowPoints =
              points.sublist(i, i + windowSize).map((p) => p.location).toList();

          // Count direction changes in the window
          int directionChanges =
              _analyzePattern(windowPoints, minDeltaThreshold);

          // Consider it a zigzag if we see at least 2 direction changes
          // (which means 3 segments going in alternating directions)
          if (directionChanges >= 2) {
            var line = LineString.from(windowPoints);
            centroid = line.centroid2D();

            if (centroid != null) {
              // Verify points are within radius of centroid
              bool allNearCenter = windowPoints.every((point) {
                var distanceLine = LineString.from([point, centroid!]);
                return distanceLine.length2D() <= zigzagRadius;
              });

              if (allNearCenter) {
                clusterEnd = i + windowSize - 1;
                isZigZag = true;

                // Try to extend the pattern
                int extendedEnd = clusterEnd;
                while (extendedEnd + 3 < points.length) {
                  var extendedPoints = points
                      .sublist(extendedEnd - 1, extendedEnd + 3)
                      .map((p) => p.location)
                      .toList();

                  // Check if extension continues the pattern
                  if (_analyzePattern(extendedPoints, minDeltaThreshold) > 0) {
                    var lastPoint = points[extendedEnd + 2].location;
                    var distanceLine = LineString.from([lastPoint, centroid!]);

                    if (distanceLine.length2D() <= zigzagRadius) {
                      extendedEnd += 2;
                      continue;
                    }
                  }
                  break;
                }

                clusterEnd = extendedEnd;
                break;
              }
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

/// Helper class to represent a direction vector
class _Direction {
  final double lon;
  final double lat;

  _Direction({required this.lon, required this.lat});
}
