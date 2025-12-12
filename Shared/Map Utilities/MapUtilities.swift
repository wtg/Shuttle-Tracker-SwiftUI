//
//  MapUtilities.swift
//  Shuttle Tracker
//
//  Geographic utilities for shuttle animation along polylines.
//

import CoreLocation

// MARK: - Find Nearest Point on Polyline

/// Result of finding the nearest point on a polyline
struct NearestPointResult {
    let index: Int                          // Index of segment start
    let point: CLLocationCoordinate2D       // Projected point on polyline
    let distance: CLLocationDistance        // Distance from target to projected point (meters)
}

/// Finds the nearest point on a polyline to a given coordinate.
/// - Parameters:
///   - target: The coordinate to find the nearest point to
///   - polyline: Array of coordinates forming the polyline
/// - Returns: The segment index, projected point, and distance
func findNearestPointOnPolyline(
    target: CLLocationCoordinate2D,
    polyline: [CLLocationCoordinate2D]
) -> NearestPointResult {
    guard polyline.count >= 2 else {
        return NearestPointResult(index: 0, point: polyline.first ?? target, distance: 0)
    }
    
    var minDistance = CLLocationDistance.infinity
    var bestIndex = 0
    var bestPoint = polyline[0]
    
    for i in 0..<(polyline.count - 1) {
        let p1 = polyline[i]
        let p2 = polyline[i + 1]
        
        let projected = projectPointOnSegment(point: target, p1: p1, p2: p2)
        let dist = distance(from: target, to: projected)
        
        if dist < minDistance {
            minDistance = dist
            bestIndex = i
            bestPoint = projected
        }
    }
    
    return NearestPointResult(index: bestIndex, point: bestPoint, distance: minDistance)
}

// MARK: - Point Projection

/// Projects a point onto a line segment.
/// Uses Euclidean approximation with longitude scaling for local accuracy.
/// - Parameters:
///   - point: The point to project
///   - p1: Start of segment
///   - p2: End of segment
/// - Returns: The projected point on the segment
private func projectPointOnSegment(
    point: CLLocationCoordinate2D,
    p1: CLLocationCoordinate2D,
    p2: CLLocationCoordinate2D
) -> CLLocationCoordinate2D {
    // Scale longitude by cos(latitude) to handle convergence at poles
    let meanLat = (p1.latitude + p2.latitude) / 2.0 * .pi / 180.0
    let cosLat = cos(meanLat)
    
    // Segment vector B
    let bx = (p2.longitude - p1.longitude) * cosLat
    let by = p2.latitude - p1.latitude
    
    // Segment length squared
    let l2 = bx * bx + by * by
    guard l2 > 0 else { return p1 }
    
    // Vector from p1 to point
    let ax = (point.longitude - p1.longitude) * cosLat
    let ay = point.latitude - p1.latitude
    
    // Project A onto B: t = (A · B) / |B|²
    var t = (ax * bx + ay * by) / l2
    t = max(0, min(1, t))  // Clamp to segment
    
    return CLLocationCoordinate2D(
        latitude: p1.latitude + t * (p2.latitude - p1.latitude),
        longitude: p1.longitude + t * (p2.longitude - p1.longitude)
    )
}

// MARK: - Move Along Polyline

/// Result of moving along a polyline
struct MoveResult {
    let index: Int
    let point: CLLocationCoordinate2D
}

/// Moves a point along the polyline by a specified distance.
/// - Parameters:
///   - polyline: The route polyline
///   - startIndex: Index of segment containing startPoint
///   - startPoint: Current position on polyline
///   - distanceMeters: Distance to move (positive = forward, negative = backward)
/// - Returns: New position on polyline
func moveAlongPolyline(
    polyline: [CLLocationCoordinate2D],
    startIndex: Int,
    startPoint: CLLocationCoordinate2D,
    distanceMeters: Double
) -> MoveResult {
    if distanceMeters < 0 {
        return moveBackward(polyline: polyline, startIndex: startIndex, startPoint: startPoint, distanceMeters: -distanceMeters)
    }
    
    var currentIndex = startIndex
    var currentPoint = startPoint
    var remainingDist = distanceMeters
    
    while remainingDist > 0 && currentIndex < polyline.count - 1 {
        let nextPoint = polyline[currentIndex + 1]
        let segmentDist = distance(from: currentPoint, to: nextPoint)
        
        if remainingDist <= segmentDist {
            // Target is on this segment
            let ratio = remainingDist / segmentDist
            let newLat = currentPoint.latitude + (nextPoint.latitude - currentPoint.latitude) * ratio
            let newLon = currentPoint.longitude + (nextPoint.longitude - currentPoint.longitude) * ratio
            return MoveResult(index: currentIndex, point: CLLocationCoordinate2D(latitude: newLat, longitude: newLon))
        } else {
            // Move to next segment
            remainingDist -= segmentDist
            currentPoint = nextPoint
            currentIndex += 1
        }
    }
    
    // Reached end of polyline
    return MoveResult(index: polyline.count - 1, point: polyline[polyline.count - 1])
}

/// Moves backward along the polyline.
private func moveBackward(
    polyline: [CLLocationCoordinate2D],
    startIndex: Int,
    startPoint: CLLocationCoordinate2D,
    distanceMeters: Double
) -> MoveResult {
    var currentIndex = startIndex
    var currentPoint = startPoint
    var remainingDist = distanceMeters
    
    while remainingDist > 0 && currentIndex >= 0 {
        let prevPoint = polyline[currentIndex]
        let segmentDist = distance(from: currentPoint, to: prevPoint)
        
        if remainingDist <= segmentDist {
            let ratio = remainingDist / segmentDist
            let newLat = currentPoint.latitude + (prevPoint.latitude - currentPoint.latitude) * ratio
            let newLon = currentPoint.longitude + (prevPoint.longitude - currentPoint.longitude) * ratio
            return MoveResult(index: currentIndex, point: CLLocationCoordinate2D(latitude: newLat, longitude: newLon))
        } else {
            remainingDist -= segmentDist
            currentPoint = prevPoint
            currentIndex -= 1
        }
    }
    
    // Reached start of polyline
    return MoveResult(index: 0, point: polyline[0])
}

// MARK: - Distance Along Polyline

/// Calculates distance along polyline between two points.
/// Handles circular routes where startIndex > endIndex.
func calculateDistanceAlongPolyline(
    polyline: [CLLocationCoordinate2D],
    startIndex: Int,
    startPoint: CLLocationCoordinate2D,
    endIndex: Int,
    endPoint: CLLocationCoordinate2D
) -> Double {
    if startIndex <= endIndex {
        return calculateForwardDistance(polyline: polyline, startIndex: startIndex, startPoint: startPoint, endIndex: endIndex, endPoint: endPoint)
    }
    
    // Circular route wrap-around
    let distToEnd = calculateForwardDistance(
        polyline: polyline,
        startIndex: startIndex,
        startPoint: startPoint,
        endIndex: polyline.count - 2,
        endPoint: polyline[polyline.count - 1]
    )
    let distFromStart = calculateForwardDistance(
        polyline: polyline,
        startIndex: 0,
        startPoint: polyline[0],
        endIndex: endIndex,
        endPoint: endPoint
    )
    return distToEnd + distFromStart
}

private func calculateForwardDistance(
    polyline: [CLLocationCoordinate2D],
    startIndex: Int,
    startPoint: CLLocationCoordinate2D,
    endIndex: Int,
    endPoint: CLLocationCoordinate2D
) -> Double {
    if startIndex == endIndex {
        return distance(from: startPoint, to: endPoint)
    }
    
    var total: Double = 0
    
    // Distance from startPoint to end of its segment
    total += distance(from: startPoint, to: polyline[startIndex + 1])
    
    // Full segments in between
    for i in (startIndex + 1)..<endIndex {
        total += distance(from: polyline[i], to: polyline[i + 1])
    }
    
    // Distance from start of end segment to endPoint
    total += distance(from: polyline[endIndex], to: endPoint)
    
    return total
}

// MARK: - Bearing Calculations

/// Calculates the initial bearing from start to end coordinate.
/// - Returns: Bearing in degrees (0-360)
func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
    let lat1 = start.latitude * .pi / 180
    let lat2 = end.latitude * .pi / 180
    let diffLong = (end.longitude - start.longitude) * .pi / 180
    
    let x = sin(diffLong) * cos(lat2)
    let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(diffLong)
    
    let initialBearing = atan2(x, y)
    return (initialBearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
}

/// Calculates the smallest difference between two angles.
/// - Returns: Difference in degrees (0-180)
func angleDifference(_ angle1: Double, _ angle2: Double) -> Double {
    let diff = abs(angle1 - angle2).truncatingRemainder(dividingBy: 360)
    return diff > 180 ? 360 - diff : diff
}

// MARK: - Helper using native CLLocation

/// Distance between two coordinates in meters using native CoreLocation.
private func distance(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> CLLocationDistance {
    let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
    let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
    return loc1.distance(from: loc2)
}
