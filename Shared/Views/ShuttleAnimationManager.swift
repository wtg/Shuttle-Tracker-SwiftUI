//
//  ShuttleAnimationManager.swift
//  Shuttle Tracker
//
//  Manages smooth animation of shuttle positions along route polylines.
//

import Combine
import CoreLocation
import Foundation
import QuartzCore
import os

/// State for animating a single vehicle
struct VehicleAnimationState {
  var polylineIndex: Int
  var currentPoint: CLLocationCoordinate2D
  var targetDistance: Double
  var distanceTraveled: Double
  var lastUpdateTime: Date
  var lastServerTimestamp: String
}

// MARK: - Constants

private enum AnimationConstants {
  /// Prediction window in seconds (matches server update interval)
  static let predictionWindowSeconds: Double = 5.0
  /// Maximum gap before snapping to server position (meters)
  static let maxReasonableGapMeters: Double = 250.0
  /// Conversion factor from mph to meters per second
  static let mphToMetersPerSecond: Double = 0.44704
  /// Maximum heading deviation before considering wrong direction (degrees)
  static let maxHeadingDeviationDegrees: Double = 90.0
  /// Maximum frame time delta before skipping animation (seconds)
  static let maxFrameDeltaSeconds: Double = 1.0
}

/// Manages smooth shuttle animation using prediction-based interpolation.
/// Uses CADisplayLink for 60fps updates, predicting shuttle positions between
/// 5-second server updates to eliminate visual "jumping".
@MainActor
class ShuttleAnimationManager: ObservableObject {
  /// Published positions for SwiftUI to observe
  @Published var animatedPositions: [String: CLLocationCoordinate2D] = [:]

  /// Internal animation state per vehicle
  private var animationStates: [String: VehicleAnimationState] = [:]

  /// Flattened route polylines for each route name
  private var routePolylines: [String: [CLLocationCoordinate2D]] = [:]

  /// Cached route keys for invalidation detection
  private var cachedRouteKeys: Set<String> = []

  /// Current vehicle data from server
  private var vehicles: VehicleInformationMap = [:]

  /// Display link for animation loop
  private var displayLink: CADisplayLink?

  /// Time of last animation frame
  private var lastFrameTime: Date = Date()

  /// Logger for diagnostics
  private let logger = Logger(subsystem: "com.shuttletracker", category: "animation")

  // MARK: - Public API

  /// Updates vehicle data and route polylines.
  /// Called when new data arrives from the API.
  func updateVehicleData(_ vehicles: VehicleInformationMap, routes: ShuttleRouteData) {
    self.vehicles = vehicles

    // Rebuild polylines if routes have changed
    let currentRouteKeys = Set(routes.keys)
    if routePolylines.isEmpty || cachedRouteKeys != currentRouteKeys {
      buildRoutePolylines(from: routes)
      cachedRouteKeys = currentRouteKeys
    }

    // Update animation states for each vehicle
    let now = Date()

    for (key, vehicle) in vehicles {
      // Skip vehicles without a valid route
      guard let routeName = vehicle.routeName,
        let polyline = routePolylines[routeName],
        polyline.count >= 2
      else {
        // Fall back to server position for unrouted vehicles
        animatedPositions[key] = CLLocationCoordinate2D(
          latitude: vehicle.latitude,
          longitude: vehicle.longitude
        )
        continue
      }

      let vehicleCoord = CLLocationCoordinate2D(
        latitude: vehicle.latitude, longitude: vehicle.longitude)
      let serverTime = vehicle.timestamp

      // Check if we already have animation state
      if let animState = animationStates[key] {
        // Skip if server data hasn't changed (cached response)
        if animState.lastServerTimestamp == serverTime {
          continue
        }

        // Calculate new target using prediction smoothing
        updateAnimationState(
          key: key, vehicle: vehicle, animState: animState, polyline: polyline, now: now)
      } else {
        // New vehicle - snap to polyline
        snapToPolyline(
          key: key, vehicleCoord: vehicleCoord, polyline: polyline, serverTime: serverTime, now: now
        )
      }
    }

    // Remove stale vehicles
    let currentKeys = Set(vehicles.keys)
    for key in animationStates.keys {
      if !currentKeys.contains(key) {
        animationStates.removeValue(forKey: key)
        animatedPositions.removeValue(forKey: key)
      }
    }
  }

  /// Starts the animation loop.
  func startAnimating() {
    guard displayLink == nil else { return }

    lastFrameTime = Date()

    // Use a trampoline to avoid capturing @MainActor self directly
    let trampoline = DisplayLinkTrampoline { [weak self] in
      Task { @MainActor in
        self?.animationTick()
      }
    }

    displayLink = CADisplayLink(target: trampoline, selector: #selector(DisplayLinkTrampoline.tick))
    displayLink?.add(to: .main, forMode: .common)
  }

  /// Stops the animation loop.
  func stopAnimating() {
    displayLink?.invalidate()
    displayLink = nil
  }

  /// Invalidates the route polyline cache, forcing a rebuild on next update.
  func invalidateRouteCache() {
    routePolylines.removeAll()
    cachedRouteKeys.removeAll()
  }

  // MARK: - Private Methods

  /// Builds flattened polyline arrays from route data.
  private func buildRoutePolylines(from routes: ShuttleRouteData) {
    routePolylines.removeAll()

    for (routeName, routeData) in routes {
      var flattenedCoords: [CLLocationCoordinate2D] = []

      for segment in routeData.routes {
        for (i, coordPair) in segment.enumerated() {
          guard coordPair.count == 2 else { continue }
          let coord = CLLocationCoordinate2D(latitude: coordPair[0], longitude: coordPair[1])

          // Avoid duplicates at segment boundaries
          if i == 0 && !flattenedCoords.isEmpty {
            if let last = flattenedCoords.last,
              abs(last.latitude - coord.latitude) < 0.00001
                && abs(last.longitude - coord.longitude) < 0.00001
            {
              continue
            }
          }
          flattenedCoords.append(coord)
        }
      }

      if flattenedCoords.count >= 2 {
        routePolylines[routeName] = flattenedCoords
      }
    }

    logger.debug("Built polylines for \(routes.count) routes")
  }

  /// Snaps a vehicle to its nearest point on the polyline.
  private func snapToPolyline(
    key: String,
    vehicleCoord: CLLocationCoordinate2D,
    polyline: [CLLocationCoordinate2D],
    serverTime: String,
    now: Date
  ) {
    let result = findNearestPointOnPolyline(target: vehicleCoord, polyline: polyline)

    animationStates[key] = VehicleAnimationState(
      polylineIndex: result.index,
      currentPoint: result.point,
      targetDistance: 0,
      distanceTraveled: 0,
      lastUpdateTime: now,
      lastServerTimestamp: serverTime
    )

    animatedPositions[key] = result.point
  }

  /// Updates animation state using prediction smoothing algorithm.
  private func updateAnimationState(
    key: String,
    vehicle: VehicleLocationData,
    animState: VehicleAnimationState,
    polyline: [CLLocationCoordinate2D],
    now: Date
  ) {
    let vehicleCoord = CLLocationCoordinate2D(
      latitude: vehicle.latitude, longitude: vehicle.longitude)

    // Step 1: Find where server says vehicle is now
    let serverResult = findNearestPointOnPolyline(target: vehicleCoord, polyline: polyline)

    // Step 2: Calculate projected target position
    let speedMetersPerSecond = vehicle.speedMph * AnimationConstants.mphToMetersPerSecond
    let projectedDistance = speedMetersPerSecond * AnimationConstants.predictionWindowSeconds

    let targetResult = moveAlongPolyline(
      polyline: polyline,
      startIndex: serverResult.index,
      startPoint: serverResult.point,
      distanceMeters: projectedDistance
    )

    // Step 3: Verify direction (optional - check heading matches route bearing)
    var isMovingCorrectDirection = true
    if polyline.count > serverResult.index + 1 && vehicle.speedMph > 1 {
      let segmentStart = polyline[serverResult.index]
      let segmentEnd = polyline[serverResult.index + 1]
      let segmentBearing = calculateBearing(from: segmentStart, to: segmentEnd)
      let headingDiff = angleDifference(segmentBearing, vehicle.headingDegrees)

      if headingDiff > AnimationConstants.maxHeadingDeviationDegrees {
        isMovingCorrectDirection = false
      }
    }

    // Step 4: Calculate distance from current visual position to target
    let distanceToTarget = calculateDistanceAlongPolyline(
      polyline: polyline,
      startIndex: animState.polylineIndex,
      startPoint: animState.currentPoint,
      endIndex: targetResult.index,
      endPoint: targetResult.point
    )

    // Step 5: Determine target distance with direction check
    var targetDistanceMeters = distanceToTarget
    if !isMovingCorrectDirection {
      targetDistanceMeters = 0
    }

    // Step 6: Snap or smooth based on gap size
    if abs(distanceToTarget) > AnimationConstants.maxReasonableGapMeters {
      // Too far - snap to server position
      snapToPolyline(
        key: key, vehicleCoord: vehicleCoord, polyline: polyline, serverTime: vehicle.timestamp,
        now: now)
    } else {
      // Smooth animation
      animationStates[key] = VehicleAnimationState(
        polylineIndex: animState.polylineIndex,
        currentPoint: animState.currentPoint,
        targetDistance: targetDistanceMeters,
        distanceTraveled: 0,
        lastUpdateTime: now,
        lastServerTimestamp: vehicle.timestamp
      )
    }
  }

  /// Animation tick called by display link trampoline.
  private func animationTick() {
    let now = Date()
    let dt = now.timeIntervalSince(lastFrameTime)
    lastFrameTime = now

    // Skip large jumps (app was backgrounded)
    guard dt < AnimationConstants.maxFrameDeltaSeconds else { return }

    for key in animationStates.keys {
      guard var animState = animationStates[key],
        let vehicle = vehicles[key],
        let routeName = vehicle.routeName,
        let polyline = routePolylines[routeName]
      else {
        continue
      }

      // Calculate progress through prediction window
      let timeElapsed = now.timeIntervalSince(animState.lastUpdateTime)
      let progress = min(timeElapsed / AnimationConstants.predictionWindowSeconds, 1.0)

      // Linear interpolation of target distance
      let targetPosition = animState.targetDistance * progress
      let distanceToMove = targetPosition - animState.distanceTraveled

      // Skip if no movement needed
      guard distanceToMove != 0 else { continue }

      // Move along polyline
      let moveResult = moveAlongPolyline(
        polyline: polyline,
        startIndex: animState.polylineIndex,
        startPoint: animState.currentPoint,
        distanceMeters: distanceToMove
      )

      // Update state
      animState.polylineIndex = moveResult.index
      animState.currentPoint = moveResult.point
      animState.distanceTraveled = targetPosition
      animationStates[key] = animState

      // Publish new position
      animatedPositions[key] = moveResult.point
    }
  }
}

// MARK: - Display Link Trampoline

/// Helper class to bridge CADisplayLink to @MainActor isolated code.
/// Avoids Swift 6 concurrency issues with capturing @MainActor self.
private class DisplayLinkTrampoline {
  private let callback: () -> Void

  init(callback: @escaping () -> Void) {
    self.callback = callback
  }

  @objc func tick() {
    callback()
  }
}
