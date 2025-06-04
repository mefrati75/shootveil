//
//  IdentificationManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import CoreLocation
import UIKit

class IdentificationManager: ObservableObject {

    // MARK: - Aircraft Identification (User-Initiated)
    func identifyAircraft(metadata: CaptureMetadata) async throws -> [Aircraft] {
        // Calculate direction vector from GPS + compass bearing
        let direction = metadata.heading
        let userLocation = metadata.gpsCoordinate

        var aircraftResults: [Aircraft] = []

        // Strategy 1: Try FlightAware API for real-time aircraft data (only if enabled and user-initiated)
        if APIConfig.Settings.flightAwareEnabled {
            do {
                print("🔍 Starting user-initiated aircraft search...")
                let flightAwareData = try await FlightAwareManager.shared.searchAircraftForUser(
                    center: userLocation,
                    radiusKm: Double(APIConfig.Settings.aircraftSearchRadius),
                    bearing: direction,
                    tolerance: APIConfig.Settings.aircraftBearingTolerance
                )

                // Convert FlightAware data to Aircraft objects
                let realAircraft = flightAwareData.compactMap { aircraftInfo -> Aircraft? in
                    let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                        .distance(from: CLLocation(latitude: aircraftInfo.coordinate.latitude, longitude: aircraftInfo.coordinate.longitude))

                    return Aircraft(
                        id: aircraftInfo.id,
                        flightNumber: aircraftInfo.flightNumber,
                        aircraftType: aircraftInfo.aircraftType,
                        airline: aircraftInfo.airline,
                        coordinate: aircraftInfo.coordinate,
                        altitude: aircraftInfo.altitude,
                        heading: aircraftInfo.heading,
                        speed: aircraftInfo.speed,
                        origin: aircraftInfo.origin,
                        destination: aircraftInfo.destination,
                        distance: distance
                    )
                }

                aircraftResults.append(contentsOf: realAircraft)
                print("✈️ FlightAware found \(realAircraft.count) real aircraft")

                // If we found real aircraft, return them (don't use fallback)
                if !aircraftResults.isEmpty {
                    return Array(aircraftResults.sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) })
                }

            } catch let error as FlightAwareError {
                switch error {
                case .quotaExceeded:
                    print("💰 Daily FlightAware quota exceeded - using local data")
                case .rateLimitExceeded:
                    print("⏱️ FlightAware rate limit exceeded - using local data")
                default:
                    print("⚠️ FlightAware API failed: \(error.localizedDescription)")
                }
            } catch {
                print("⚠️ FlightAware API failed: \(error.localizedDescription)")
            }
        } else {
            print("✈️ FlightAware API disabled - using local data")
        }

        // Strategy 2: Use local data as fallback if no real aircraft found or API failed
        if aircraftResults.isEmpty && APIConfig.Settings.localDataFallback {
            print("📍 Using local aircraft data as fallback...")
            let localAircraftData = LocalDataSource.getAircraftByBearing(
                from: userLocation,
                bearing: direction,
                tolerance: APIConfig.Settings.aircraftBearingTolerance,
                radiusKm: Double(APIConfig.Settings.aircraftSearchRadius)
            )

            let localAircraft = localAircraftData.compactMap { aircraftInfo -> Aircraft? in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: aircraftInfo.coordinate.latitude, longitude: aircraftInfo.coordinate.longitude))

                return Aircraft(
                    id: aircraftInfo.id,
                    flightNumber: aircraftInfo.flightNumber,
                    aircraftType: aircraftInfo.aircraftType,
                    airline: aircraftInfo.airline,
                    coordinate: aircraftInfo.coordinate,
                    altitude: aircraftInfo.altitude,
                    heading: aircraftInfo.heading,
                    speed: aircraftInfo.speed,
                    origin: aircraftInfo.origin,
                    destination: aircraftInfo.destination,
                    distance: distance
                )
            }

            aircraftResults.append(contentsOf: localAircraft)
            print("📍 Local data provided \(localAircraft.count) sample aircraft")
        }

        // Sort by distance and return closest matches
        return Array(aircraftResults.sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }.prefix(APIConfig.Settings.maxAircraftResults))
    }

    // MARK: - Automatic Aircraft Detection When Taking Photos
    func detectAircraftInPhoto(metadata: CaptureMetadata) async throws -> [Aircraft] {
        print("🎯 Automatic aircraft detection triggered")
        print("📍 Location: \(metadata.gpsCoordinate.latitude), \(metadata.gpsCoordinate.longitude)")
        print("🧭 Camera heading: \(metadata.heading)°")
        print("📐 Camera pitch: \(metadata.pitch)°")
        print("🔍 Field of view: \(metadata.effectiveFieldOfView)°")

        let direction = metadata.heading
        let userLocation = metadata.gpsCoordinate
        let cameraPitch = metadata.pitch
        let fieldOfView = metadata.effectiveFieldOfView

        var aircraftResults: [Aircraft] = []

        // Strategy 1: Try FlightAware API for real-time aircraft data
        if APIConfig.Settings.flightAwareEnabled {
            do {
                print("🔍 Starting automatic aircraft detection...")

                // Use tighter bearing tolerance for automatic detection
                let bearingTolerance = min(fieldOfView / 2, APIConfig.Settings.aircraftBearingTolerance)

                let flightAwareData = try await FlightAwareManager.shared.searchAircraftForUser(
                    center: userLocation,
                    radiusKm: Double(APIConfig.Settings.aircraftSearchRadius),
                    bearing: direction,
                    tolerance: bearingTolerance
                )

                // Convert FlightAware data to Aircraft objects with distance filtering
                let realAircraft = flightAwareData.compactMap { aircraftInfo -> Aircraft? in
                    let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                        .distance(from: CLLocation(latitude: aircraftInfo.coordinate.latitude, longitude: aircraftInfo.coordinate.longitude))

                    // Filter by elevation angle if we have pitch data
                    if abs(cameraPitch) > 5 { // Only filter if camera is significantly tilted up/down
                        let elevationAngle = calculateElevationAngle(
                            userLocation: userLocation,
                            userAltitude: metadata.altitude,
                            aircraftLocation: aircraftInfo.coordinate,
                            aircraftAltitude: aircraftInfo.altitude * 0.3048 // Convert feet to meters
                        )

                        let pitchTolerance: Double = 15.0 // degrees
                        let pitchDiff = abs(cameraPitch - elevationAngle)

                        // Skip aircraft that don't match the camera's elevation angle
                        if pitchDiff > pitchTolerance {
                            print("📐 Filtered out \(aircraftInfo.flightNumber ?? "Unknown") - elevation mismatch: camera \(String(format: "%.1f", cameraPitch))°, aircraft \(String(format: "%.1f", elevationAngle))°")
                            return nil
                        }
                    }

                    return Aircraft(
                        id: aircraftInfo.id,
                        flightNumber: aircraftInfo.flightNumber,
                        aircraftType: aircraftInfo.aircraftType,
                        airline: aircraftInfo.airline,
                        coordinate: aircraftInfo.coordinate,
                        altitude: aircraftInfo.altitude,
                        heading: aircraftInfo.heading,
                        speed: aircraftInfo.speed,
                        origin: aircraftInfo.origin,
                        destination: aircraftInfo.destination,
                        distance: distance
                    )
                }

                aircraftResults.append(contentsOf: realAircraft)
                print("✈️ Automatic detection found \(realAircraft.count) aircraft in camera direction")

                // If we found real aircraft, return them (prioritize real data)
                if !aircraftResults.isEmpty {
                    return Array(aircraftResults.sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }.prefix(3)) // Limit to 3 most likely aircraft
                }

            } catch let error as FlightAwareError {
                switch error {
                case .quotaExceeded:
                    print("💰 Daily FlightAware quota exceeded - using local data")
                case .rateLimitExceeded:
                    print("⏱️ FlightAware rate limit exceeded - using local data")
                default:
                    print("⚠️ FlightAware API failed: \(error.localizedDescription)")
                }
            } catch {
                print("⚠️ FlightAware API failed: \(error.localizedDescription)")
            }
        }

        // Strategy 2: Use local data as fallback if no real aircraft found
        if aircraftResults.isEmpty && APIConfig.Settings.localDataFallback {
            print("📍 Using local aircraft data for automatic detection...")

            let bearingTolerance = min(fieldOfView / 2, APIConfig.Settings.aircraftBearingTolerance)

            let localAircraftData = LocalDataSource.getAircraftByBearing(
                from: userLocation,
                bearing: direction,
                tolerance: bearingTolerance,
                radiusKm: Double(APIConfig.Settings.aircraftSearchRadius)
            )

            let localAircraft = localAircraftData.compactMap { aircraftInfo -> Aircraft? in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: aircraftInfo.coordinate.latitude, longitude: aircraftInfo.coordinate.longitude))

                return Aircraft(
                    id: aircraftInfo.id,
                    flightNumber: aircraftInfo.flightNumber,
                    aircraftType: aircraftInfo.aircraftType,
                    airline: aircraftInfo.airline,
                    coordinate: aircraftInfo.coordinate,
                    altitude: aircraftInfo.altitude,
                    heading: aircraftInfo.heading,
                    speed: aircraftInfo.speed,
                    origin: aircraftInfo.origin,
                    destination: aircraftInfo.destination,
                    distance: distance
                )
            }

            aircraftResults.append(contentsOf: localAircraft)
            print("📍 Local data provided \(localAircraft.count) sample aircraft for automatic detection")
        }

        // Sort by distance and return closest matches
        let sortedResults = aircraftResults.sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }

        if sortedResults.isEmpty {
            print("📷 No aircraft detected in photo direction")
        } else {
            print("🎯 Automatic detection completed: \(sortedResults.count) aircraft found")
            for aircraft in sortedResults.prefix(3) {
                print("   ✈️ \(aircraft.flightNumber ?? "Unknown") - \(String(format: "%.0f", aircraft.distance ?? 0))m away")
            }
        }

        return Array(sortedResults.prefix(APIConfig.Settings.maxAircraftResults))
    }

    // MARK: - Enhanced Building Identification (Local + Google APIs)
    func identifyBuilding(tapPoint: CGPoint, imageSize: CGSize, metadata: CaptureMetadata, capturedImage: UIImage? = nil) async throws -> [Building] {
        // Convert tap coordinates to real-world bearing
        let targetBearing = calculateBearingFromTap(
            tapPoint: tapPoint,
            imageSize: imageSize,
            metadata: metadata
        )

        let userLocation = metadata.gpsCoordinate

        // Strategy 1: Try Google Gemini AI for image recognition (if image provided)
        var geminiResults: [BuildingAPIResponse] = []
        if let image = capturedImage {
            do {
                geminiResults = try await GoogleAPIManager.shared.identifyBuildingFromImage(image, at: userLocation)
                print("✅ Gemini AI identified \(geminiResults.count) buildings")
            } catch {
                print("⚠️ Gemini AI failed: \(error.localizedDescription)")
            }
        }

        // Strategy 2: Use Google Places API for nearby buildings
        var placesResults: [BuildingAPIResponse] = []
        do {
            placesResults = try await GoogleAPIManager.shared.findBuildingsNearLocation(userLocation, radius: 2000)
            print("✅ Google Places found \(placesResults.count) buildings")
        } catch {
            print("⚠️ Google Places failed: \(error.localizedDescription)")
        }

        // Strategy 3: Use local data as fallback
        let localResults = LocalDataSource.getBuildingsByBearing(
            from: userLocation,
            bearing: targetBearing,
            tolerance: 8.0, // Wider tolerance for buildings (user might not tap exactly)
            radiusKm: 50 // 50km search radius for buildings
        )
        print("📍 Local data found \(localResults.count) buildings")

        // Combine all results, prioritizing Gemini > Places > Local
        var allBuildingData: [BuildingAPIResponse] = []

        // Add Gemini results first (highest priority)
        allBuildingData.append(contentsOf: geminiResults)

        // Add Places results, filtering by bearing
        let filteredPlacesResults = placesResults.filter { building in
            let buildingBearing = calculateBearing(from: userLocation, to: building.coordinate)
            let bearingDiff = abs(buildingBearing - targetBearing)
            let normalizedDiff = min(bearingDiff, 360 - bearingDiff)
            return normalizedDiff <= 15.0 // Wider tolerance for Places API
        }
        allBuildingData.append(contentsOf: filteredPlacesResults)

        // Add local results last (fallback)
        allBuildingData.append(contentsOf: localResults)

        // Convert to Building objects and calculate distances
        let buildingResults = allBuildingData.compactMap { buildingInfo -> Building? in
            let distance = calculateEnhancedDistance(
                to: buildingInfo.coordinate,
                objectHeight: buildingInfo.height > 0 ? buildingInfo.height : nil,
                tapPoint: tapPoint,
                imageSize: imageSize,
                metadata: metadata
            )

            return Building(
                id: buildingInfo.id,
                name: buildingInfo.name,
                coordinate: buildingInfo.coordinate,
                height: buildingInfo.height,
                type: buildingInfo.type,
                description: buildingInfo.description,
                wikipediaURL: buildingInfo.wikipediaURL,
                constructionYear: buildingInfo.constructionYear,
                distance: distance,
                address: nil, // Will be populated below
                isLandmark: false, // Will be determined below
                landmarkCategory: nil // Will be determined below
            )
        }

        // Enhance buildings with address and landmark information
        var enhancedBuildings: [Building] = []
        for building in buildingResults {
            var enhancedBuilding = building

            // Get address via reverse geocoding
            do {
                print("🗺️ Attempting reverse geocoding for \(building.name) at \(building.coordinate)")
                let address = try await GoogleAPIManager.shared.reverseGeocode(coordinate: building.coordinate)
                print("✅ Got address: \(address)")
                enhancedBuilding = Building(
                    id: building.id,
                    name: building.name,
                    coordinate: building.coordinate,
                    height: building.height,
                    type: building.type,
                    description: building.description,
                    wikipediaURL: building.wikipediaURL,
                    constructionYear: building.constructionYear,
                    distance: building.distance,
                    address: address,
                    isLandmark: building.isLandmark,
                    landmarkCategory: building.landmarkCategory
                )
            } catch {
                print("❌ Failed to get address for \(building.name): \(error)")
                // Still create the building without address
                enhancedBuilding = Building(
                    id: building.id,
                    name: building.name,
                    coordinate: building.coordinate,
                    height: building.height,
                    type: building.type,
                    description: building.description,
                    wikipediaURL: building.wikipediaURL,
                    constructionYear: building.constructionYear,
                    distance: building.distance,
                    address: nil,
                    isLandmark: building.isLandmark,
                    landmarkCategory: building.landmarkCategory
                )
            }

            // Determine if this is a landmark and categorize it
            let (isLandmark, category) = categorizeLandmark(building: enhancedBuilding)
            enhancedBuilding = Building(
                id: enhancedBuilding.id,
                name: enhancedBuilding.name,
                coordinate: enhancedBuilding.coordinate,
                height: enhancedBuilding.height,
                type: enhancedBuilding.type,
                description: enhancedBuilding.description,
                wikipediaURL: enhancedBuilding.wikipediaURL,
                constructionYear: enhancedBuilding.constructionYear,
                distance: enhancedBuilding.distance,
                address: enhancedBuilding.address,
                isLandmark: isLandmark,
                landmarkCategory: category
            )

            enhancedBuildings.append(enhancedBuilding)
        }

        // Remove duplicates based on name similarity
        let uniqueBuildings = removeDuplicateBuildings(enhancedBuildings)

        // Apply line-of-sight filtering
        let visibleBuildings = applyLineOfSightFiltering(
            buildings: uniqueBuildings,
            viewerLocation: userLocation,
            viewerAltitude: metadata.altitude
        )

        // Sort by distance and return top candidates
        return Array(visibleBuildings.sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }.prefix(5))
    }

    // MARK: - Helper Methods
    private func removeDuplicateBuildings(_ buildings: [Building]) -> [Building] {
        var uniqueBuildings: [Building] = []

        for building in buildings {
            let isDuplicate = uniqueBuildings.contains { existingBuilding in
                // Check if names are similar (case-insensitive, allowing for slight variations)
                let similarity = stringSimilarity(building.name.lowercased(), existingBuilding.name.lowercased())
                return similarity > 0.8 // 80% similarity threshold
            }

            if !isDuplicate {
                uniqueBuildings.append(building)
            }
        }

        return uniqueBuildings
    }

    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1

        if longer.isEmpty { return 1.0 }

        let distance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(distance)) / Double(longer.count)
    }

    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count

        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)

        for i in 0...str1Count {
            matrix[i][0] = i
        }

        for j in 0...str2Count {
            matrix[0][j] = j
        }

        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[str1Count][str2Count]
    }

    private func calculateBearingFromTap(tapPoint: CGPoint, imageSize: CGSize, metadata: CaptureMetadata) -> Double {
        let effectiveFOV = metadata.effectiveFieldOfView
        let centerOffset = (tapPoint.x / imageSize.width) - 0.5 // -0.5 to 0.5
        let bearingOffset = centerOffset * effectiveFOV

        var targetBearing = metadata.heading + bearingOffset

        // Normalize to 0-360 degrees
        if targetBearing < 0 {
            targetBearing += 360
        } else if targetBearing >= 360 {
            targetBearing -= 360
        }

        print("🎯 Calculated bearing: \(targetBearing)° (FOV: \(effectiveFOV)°, Zoom: \(metadata.zoomFactor)x)")
        return targetBearing
    }

    private func applyLineOfSightFiltering(buildings: [Building], viewerLocation: CLLocationCoordinate2D, viewerAltitude: Double) -> [Building] {
        // Enhanced line-of-sight filtering
        let sortedByDistance = buildings.sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }
        var visibleBuildings: [Building] = []

        for building in sortedByDistance {
            var isVisible = true

            // Check if any closer building blocks this one
            for closerBuilding in visibleBuildings {
                if let buildingDistance = building.distance,
                   let closerDistance = closerBuilding.distance,
                   closerDistance < buildingDistance {

                    // Simple line-of-sight check based on angle and height
                    let angleDifference = abs(calculateBearing(from: viewerLocation, to: building.coordinate) -
                                            calculateBearing(from: viewerLocation, to: closerBuilding.coordinate))

                    // If buildings are very close in angle and the closer one is taller, it might block the view
                    if angleDifference < 2.0 && closerBuilding.height > building.height {
                        // Calculate if the closer building would block the view
                        let viewAngleToCloser = atan(closerBuilding.height / closerDistance) * 180 / .pi
                        let viewAngleToTarget = atan(building.height / buildingDistance) * 180 / .pi

                        if viewAngleToCloser >= viewAngleToTarget {
                            isVisible = false
                            break
                        }
                    }
                }
            }

            if isVisible {
                visibleBuildings.append(building)
            }
        }

        return visibleBuildings
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Enhanced Distance Estimation with Zoom

    // Estimate distance based on object angular size and zoom
    private func estimateDistance(objectHeightMeters: Double, tapPoint: CGPoint, imageSize: CGSize, metadata: CaptureMetadata) -> Double? {
        // Calculate object's angular size in the image
        let objectHeightPixels = imageSize.height * 0.1 // Assume object takes ~10% of image height (adjustable)
        let angularSizeRadians = (objectHeightPixels / imageSize.height) * (metadata.effectiveFieldOfView * .pi / 180)

        // Distance = actual_height / tan(angular_size)
        let estimatedDistance = objectHeightMeters / tan(angularSizeRadians)

        print("📏 Distance estimate: \(estimatedDistance)m (object: \(objectHeightMeters)m, angular size: \(angularSizeRadians * 180 / .pi)°)")
        return estimatedDistance
    }

    // Enhanced distance calculation considering zoom and object characteristics
    private func calculateEnhancedDistance(to coordinate: CLLocationCoordinate2D, objectHeight: Double?, tapPoint: CGPoint?, imageSize: CGSize?, metadata: CaptureMetadata) -> Double {
        let userLocation = metadata.gpsCoordinate

        // Primary distance: GPS-based calculation
        let gpsDistance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

        // Secondary distance: Angular size estimation (if we have object height and tap point)
        var angularDistance: Double?
        if let objectHeight = objectHeight,
           let tapPoint = tapPoint,
           let imageSize = imageSize,
           objectHeight > 0 {
            angularDistance = estimateDistance(objectHeightMeters: objectHeight, tapPoint: tapPoint, imageSize: imageSize, metadata: metadata)
        }

        // Use angular distance if available and reasonable, otherwise use GPS distance
        if let angularDistance = angularDistance,
           angularDistance > 0,
           angularDistance < gpsDistance * 2 { // Sanity check: angular estimate shouldn't be more than 2x GPS distance
            print("🎯 Using angular distance: \(angularDistance)m vs GPS: \(gpsDistance)m")
            return angularDistance
        } else {
            print("📍 Using GPS distance: \(gpsDistance)m")
            return gpsDistance
        }
    }

    private func categorizeLandmark(building: Building) -> (Bool, LandmarkCategory?) {
        let name = building.name.lowercased()
        let type = building.type

        // Religious buildings
        if name.contains("church") || name.contains("cathedral") || name.contains("chapel") ||
           name.contains("mosque") || name.contains("synagogue") || name.contains("temple") ||
           name.contains("basilica") || name.contains("abbey") || name.contains("monastery") {
            return (true, .religiousBuilding)
        }

        // Government buildings
        if name.contains("capitol") || name.contains("city hall") || name.contains("courthouse") ||
           name.contains("white house") || name.contains("parliament") || name.contains("congress") ||
           name.contains("federal") || type == .government {
            return (true, .government)
        }

        // Monuments and memorials
        if name.contains("monument") || name.contains("memorial") || name.contains("statue") ||
           name.contains("obelisk") || name.contains("arch") {
            return (true, .monument)
        }

        // Towers and observation points
        if name.contains("tower") && (name.contains("observation") || name.contains("space") ||
           name.contains("cn") || name.contains("eiffel") || name.contains("liberty")) {
            return (true, .tower)
        }

        // Bridges
        if name.contains("bridge") && (name.contains("golden gate") || name.contains("brooklyn") ||
           name.contains("london") || name.contains("tower bridge") || building.height < 50) {
            return (true, .bridge)
        }

        // Museums
        if name.contains("museum") || name.contains("gallery") || name.contains("art") ||
           name.contains("history") || name.contains("science") {
            return (true, .museum)
        }

        // Famous architectural landmarks
        let famousLandmarks = [
            "empire state", "chrysler building", "one world trade", "freedom tower",
            "transamerica pyramid", "salesforce tower", "space needle", "willis tower",
            "sears tower", "burj", "taipei 101", "petronas", "cn tower", "big ben",
            "eiffel tower", "statue of liberty", "hollywood sign", "golden gate bridge"
        ]

        for landmark in famousLandmarks {
            if name.contains(landmark) {
                return (true, .architecture)
            }
        }

        // Historical sites based on construction year
        if let year = building.constructionYear, year < 1900 {
            return (true, .historicalSite)
        }

        // Tourist attractions (has Wikipedia URL and is a landmark type)
        if building.wikipediaURL != nil && type == .landmark {
            return (true, .touristAttraction)
        }

        // Cultural sites
        if name.contains("opera") || name.contains("theater") || name.contains("concert") ||
           name.contains("cultural") || name.contains("arts") {
            return (true, .culturalSite)
        }

        // If it's marked as a landmark type but doesn't fit other categories
        if type == .landmark {
            return (true, .touristAttraction)
        }

        return (false, nil)
    }

    // MARK: - Helper Methods for Automatic Detection
    private func calculateElevationAngle(userLocation: CLLocationCoordinate2D, userAltitude: Double, aircraftLocation: CLLocationCoordinate2D, aircraftAltitude: Double) -> Double {
        // Calculate horizontal distance
        let horizontalDistance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            .distance(from: CLLocation(latitude: aircraftLocation.latitude, longitude: aircraftLocation.longitude))

        // Calculate vertical distance (altitude difference)
        let verticalDistance = aircraftAltitude - userAltitude

        // Calculate elevation angle in degrees
        let elevationAngleRadians = atan2(verticalDistance, horizontalDistance)
        let elevationAngleDegrees = elevationAngleRadians * 180.0 / .pi

        return elevationAngleDegrees
    }
}

// MARK: - Data Models for API Responses (keep for compatibility)
struct BoundingBox {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
}

struct AircraftAPIResponse {
    let id: String
    let flightNumber: String?
    let aircraftType: String
    let airline: String?
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let heading: Double
    let speed: Double
    let origin: String?
    let destination: String?
}

struct BuildingAPIResponse {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let height: Double
    let type: BuildingType
    let description: String
    let wikipediaURL: String?
    let constructionYear: Int?
}

// MARK: - Network Manager (simplified for local data)
class NetworkManager {
    // Placeholder for future API integration if needed
}
