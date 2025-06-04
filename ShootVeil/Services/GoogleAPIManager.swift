//
//  GoogleAPIManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import UIKit
import CoreLocation

class GoogleAPIManager {
    static let shared = GoogleAPIManager()

    // Use centralized API configuration
    private let apiKey = "AIzaSyCtMZ-KDXdKlR74MFarqpjSZYllEl-FjhM"
    private let baseURL = "https://maps.googleapis.com/maps/api/geocode/json"

    // API Endpoints from config
    private let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    private let geocodingEndpoint = APIConfig.GoogleAPIs.geocoding
    private let placesEndpoint = APIConfig.GoogleAPIs.places

    // Gemini AI Configuration
    private let geminiApiKey = "AIzaSyCtMZ-KDXdKlR74MFarqpjSZYllEl-FjhM" // Use same API key for Gemini

    private init() {
        // Print API status on initialization
        APIConfig.checkAPIStatus()
    }

    // MARK: - Gemini AI for Image Recognition
    func identifyBuildingFromImage(_ image: UIImage, at location: CLLocationCoordinate2D) async throws -> [BuildingAPIResponse] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()

        let prompt = """
        Identify the buildings and landmarks in this image. I'm located at coordinates \(location.latitude), \(location.longitude).
        Please provide:
        1. Name of each building/landmark visible
        2. Brief description
        3. Construction year if known
        4. Type (landmark, office, residential, etc.)

        Format the response as JSON with this structure:
        {
          "buildings": [
            {
              "name": "Building Name",
              "description": "Brief description",
              "type": "landmark|office|residential|commercial|government|religious|educational|industrial|other",
              "constructionYear": year or null
            }
          ]
        }
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw APIError.requestCreationFailed
        }

        var request = URLRequest(url: URL(string: "\(geminiEndpoint)?key=\(geminiApiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.networkError
        }

        // Parse Gemini response and convert to BuildingAPIResponse
        return try parseGeminiResponse(data, userLocation: location)
    }

    // MARK: - Geocoding API for Building Data
    func findBuildingsNearLocation(_ location: CLLocationCoordinate2D, radius: Int = 1000) async throws -> [BuildingAPIResponse] {
        let url = "\(placesEndpoint)?location=\(location.latitude),\(location.longitude)&radius=\(radius)&type=establishment&key=\(apiKey)"

        guard let requestURL = URL(string: url) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: requestURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.networkError
        }

        return try parseGeocodingResponse(data)
    }

    // MARK: - Reverse Geocoding
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        // Use the exact API endpoint format specified by user
        let baseURL = "https://maps.googleapis.com/maps/api/geocode/json"
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        let apiKey = APIConfig.googleAPIKey

        // Build URL exactly as specified: https://maps.googleapis.com/maps/api/geocode/json?latlng={LAT},{LNG}&key=YOUR_API_KEY
        let urlString = "\(baseURL)?latlng=\(lat),\(lng)&key=\(apiKey)"

        guard let requestURL = URL(string: urlString) else {
            print("❌ Invalid geocoding URL: \(urlString)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        print("🗺️ Reverse geocoding request:")
        print("📍 Coordinate: \(lat), \(lng)")
        print("🔗 Full URL: \(urlString)")
        print("🔑 API Key: \(apiKey)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw APIError.networkError
            }

            print("📡 HTTP Status: \(httpResponse.statusCode)")

            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw Response (first 500 chars): \(String(responseString.prefix(500)))")
            }

            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ API Error Response: \(responseString)")

                    // Check for specific Google API errors
                    if responseString.contains("API_KEY_INVALID") {
                        print("🔑 Invalid API key")
                        throw APIError.apiKeyInvalid
                    } else if responseString.contains("BILLING_NOT_ENABLED") {
                        print("💳 Billing not enabled for this API")
                        throw APIError.billingNotEnabled
                    } else if responseString.contains("API_NOT_ENABLED") || responseString.contains("This API project is not authorized to use this API") {
                        print("🚫 Geocoding API not enabled")
                        throw APIError.apiNotEnabled
                    } else if responseString.contains("OVER_DAILY_LIMIT") {
                        print("📊 Daily quota exceeded")
                        throw APIError.quotaExceeded
                    } else if responseString.contains("OVER_QUERY_LIMIT") {
                        print("📊 Query rate limit exceeded")
                        throw APIError.quotaExceeded
                    }
                }
                throw APIError.networkError
            }

            let geocodingResponse = try JSONDecoder().decode(GeocodingResponse.self, from: data)
            print("📍 Geocoding API Status: \(geocodingResponse.status)")
            print("📍 Results count: \(geocodingResponse.results.count)")

            guard geocodingResponse.status == "OK" else {
                print("❌ Geocoding API returned status: \(geocodingResponse.status)")

                // Handle specific status codes
                switch geocodingResponse.status {
                case "ZERO_RESULTS":
                    print("🔍 No address found for these coordinates")
                    return "Location Not Found"
                case "OVER_DAILY_LIMIT":
                    print("📊 Daily API quota exceeded")
                    return "Address Unavailable (Quota Exceeded)"
                case "OVER_QUERY_LIMIT":
                    print("📊 Query rate limit exceeded")
                    return "Address Unavailable (Rate Limited)"
                case "REQUEST_DENIED":
                    print("🚫 API request denied - Geocoding API not enabled for this project")
                    throw APIError.apiNotEnabled
                case "INVALID_REQUEST":
                    print("⚠️ Invalid request parameters")
                    return "Address Unavailable (Invalid Request)"
                default:
                    return "Address Unavailable"
                }
            }

            guard let firstResult = geocodingResponse.results.first else {
                print("⚠️ No results from geocoding API")
                return "Unknown Location"
            }

            // First, check all results for landmarks/points of interest
            for result in geocodingResponse.results {
                if let landmarkName = extractLandmarkName(from: result) {
                    print("🏛️ Found landmark: \(landmarkName)")
                    return landmarkName
                }
            }

            // If no landmarks found, try to get a nice formatted address from the first result
            if !firstResult.formatted_address.isEmpty {
                print("✅ Found formatted address: \(firstResult.formatted_address)")
                return firstResult.formatted_address
            }

            // Fallback to component-based address
            var addressComponents: [String] = []

            for component in firstResult.address_components {
                if component.types.contains("street_number") || component.types.contains("route") {
                    addressComponents.append(component.long_name)
                } else if component.types.contains("locality") || component.types.contains("sublocality") {
                    if addressComponents.count < 3 {
                        addressComponents.append(component.long_name)
                    }
                }
            }

            let address = addressComponents.joined(separator: " ")
            print("📍 Component-based address: \(address)")
            return address.isEmpty ? "Unknown Location" : address

        } catch let decodingError as DecodingError {
            print("❌ JSON Decoding Error: \(decodingError)")
            throw APIError.responseParsingFailed
        } catch {
            print("❌ Network Error: \(error)")
            throw APIError.networkError
        }
    }

    // MARK: - Landmark Detection Helper
    private func extractLandmarkName(from result: GeocodingResult) -> String? {
        // Check if this result contains landmark types
        let landmarkTypes: Set<String> = [
            "point_of_interest",
            "establishment",
            "tourist_attraction",
            "natural_feature",
            "premise",
            "museum",
            "church",
            "synagogue",
            "mosque",
            "university",
            "school",
            "hospital",
            "park",
            "stadium",
            "amusement_park",
            "zoo",
            "aquarium",
            "art_gallery",
            "library",
            "movie_theater",
            "shopping_mall",
            "restaurant",
            "cafe",
            "lodging",
            "airport",
            "train_station",
            "subway_station",
            "bus_station",
            "gas_station",
            "embassy",
            "city_hall",
            "courthouse",
            "fire_station",
            "police",
            "post_office",
            "bank",
            "atm",
            "pharmacy",
            "veterinary_care",
            "spa",
            "gym",
            "beauty_salon",
            "laundry",
            "car_rental",
            "car_repair",
            "real_estate_agency",
            "insurance_agency",
            "travel_agency",
            "electrician",
            "plumber",
            "roofing_contractor",
            "painter",
            "moving_company",
            "storage"
        ]

        // Check if any of the result types match landmark types
        let hasLandmarkType = result.types.contains { landmarkTypes.contains($0) }

        if hasLandmarkType {
            // Try to find a good name from address components
            for component in result.address_components {
                // Look for establishment name, point of interest name, or premise name
                if component.types.contains("establishment") ||
                   component.types.contains("point_of_interest") ||
                   component.types.contains("premise") ||
                   component.types.contains("natural_feature") {
                    print("🏛️ Found landmark component: \(component.long_name) (types: \(component.types))")
                    return component.long_name
                }
            }

            // If no specific landmark component found, but it's marked as a landmark type,
            // try to extract a meaningful name from the formatted address
            let formattedAddress = result.formatted_address
            if !formattedAddress.isEmpty {
                // Extract the first part before the first comma (often the landmark name)
                if let firstPart = formattedAddress.split(separator: ",").first {
                    let landmarkName = String(firstPart).trimmingCharacters(in: .whitespaces)

                    // Check if it looks like a landmark name (not just a street number)
                    if !landmarkName.isEmpty && !landmarkName.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
                        print("🏛️ Extracted landmark from formatted address: \(landmarkName)")
                        return landmarkName
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Response Parsing
    private func parseGeminiResponse(_ data: Data, userLocation: CLLocationCoordinate2D) throws -> [BuildingAPIResponse] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw APIError.responseParsingFailed
        }

        // Extract JSON from Gemini's response text
        guard let jsonStartIndex = text.range(of: "{")?.lowerBound,
              let jsonEndIndex = text.range(of: "}", options: .backwards)?.upperBound else {
            throw APIError.responseParsingFailed
        }

        let jsonString = String(text[jsonStartIndex..<jsonEndIndex])
        guard let jsonData = jsonString.data(using: .utf8),
              let buildingData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let buildings = buildingData["buildings"] as? [[String: Any]] else {
            throw APIError.responseParsingFailed
        }

        return buildings.compactMap { buildingInfo in
            guard let name = buildingInfo["name"] as? String,
                  let description = buildingInfo["description"] as? String,
                  let typeString = buildingInfo["type"] as? String,
                  let type = BuildingType(rawValue: typeString) else {
                return nil
            }

            let constructionYear = buildingInfo["constructionYear"] as? Int

            // For Gemini-identified buildings, we don't have exact coordinates
            // so we'll use approximate location near the user
            let approximateCoordinate = CLLocationCoordinate2D(
                latitude: userLocation.latitude + Double.random(in: -0.01...0.01),
                longitude: userLocation.longitude + Double.random(in: -0.01...0.01)
            )

            return BuildingAPIResponse(
                id: "gemini_\(UUID().uuidString)",
                name: name,
                coordinate: approximateCoordinate,
                height: Double.random(in: 30...400), // Estimate height
                type: type,
                description: description,
                wikipediaURL: nil,
                constructionYear: constructionYear
            )
        }
    }

    private func parseGeocodingResponse(_ data: Data) throws -> [BuildingAPIResponse] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw APIError.responseParsingFailed
        }

        return results.compactMap { result in
            guard let name = result["name"] as? String,
                  let geometry = result["geometry"] as? [String: Any],
                  let location = geometry["location"] as? [String: Double],
                  let lat = location["lat"],
                  let lng = location["lng"] else {
                return nil
            }

            let types = result["types"] as? [String] ?? []
            let buildingType: BuildingType = determineBuildingType(from: types)

            return BuildingAPIResponse(
                id: "places_\(result["place_id"] as? String ?? UUID().uuidString)",
                name: name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                height: Double.random(in: 10...200),
                type: buildingType,
                description: result["vicinity"] as? String ?? "",
                wikipediaURL: nil,
                constructionYear: nil
            )
        }
    }

    private func determineBuildingType(from types: [String]) -> BuildingType {
        for type in types {
            switch type {
            case "tourist_attraction", "museum", "church", "synagogue", "mosque":
                return .landmark
            case "school", "university":
                return .educational
            case "hospital", "doctor", "pharmacy":
                return .commercial
            case "bank", "atm", "finance":
                return .office
            case "restaurant", "food", "meal_takeaway", "cafe":
                return .commercial
            case "lodging":
                return .commercial
            case "government":
                return .government
            default:
                continue
            }
        }
        return .other
    }

    // MARK: - API Testing & Verification
    static func testGeocodingAPI() async {
        let manager = GoogleAPIManager.shared

        // Test with a well-known location - Google's headquarters
        let testCoordinate = CLLocationCoordinate2D(latitude: 37.4267861, longitude: -122.0806032)

        print("🧪 Testing Google Geocoding API...")
        print("🔑 API Key: \(APIConfig.googleAPIKey)")
        print("📍 Test coordinate: \(testCoordinate.latitude), \(testCoordinate.longitude)")

        do {
            let address = try await manager.reverseGeocode(coordinate: testCoordinate)
            print("✅ Geocoding API test successful!")
            print("📍 Address: \(address)")
        } catch {
            print("❌ Geocoding API test failed: \(error)")
            if let apiError = error as? APIError {
                switch apiError {
                case .billingNotEnabled:
                    print("💳 Solution: Enable billing on your Google Cloud project")
                case .apiNotEnabled:
                    print("🔧 Solution: Enable the Geocoding API in your Google Cloud project")
                case .apiKeyInvalid:
                    print("🔑 Solution: Check your API key is correct")
                case .quotaExceeded:
                    print("📊 Solution: Check your API quota and billing")
                default:
                    print("🔍 Check the error details above")
                }
            }
        }
    }

    // Simple test to verify exact endpoint format
    static func verifyEndpointFormat() {
        let lat = 37.7749
        let lng = -122.4194
        let apiKey = APIConfig.googleAPIKey

        // Build URL exactly as user specified: https://maps.googleapis.com/maps/api/geocode/json?latlng={LAT},{LNG}&key=YOUR_API_KEY
        let baseURL = "https://maps.googleapis.com/maps/api/geocode/json"
        let urlString = "\(baseURL)?latlng=\(lat),\(lng)&key=\(apiKey)"

        print("🔗 Endpoint format verification:")
        print("🎯 Expected format: https://maps.googleapis.com/maps/api/geocode/json?latlng={LAT},{LNG}&key=YOUR_API_KEY")
        print("✅ Actual URL:     \(urlString)")
        print("📊 Format matches: \(urlString.contains("maps.googleapis.com/maps/api/geocode/json?latlng=") && urlString.contains("&key="))")
    }

    // Manual test method that we can call from a button
    static func manualGeocodingTest() async -> String {
        let manager = GoogleAPIManager.shared

        // Test with landmark locations
        let testCoordinates = [
            // Statue of Liberty (should return landmark name)
            (40.6892, -74.0445, "Statue of Liberty"),
            // Eiffel Tower (should return landmark name)
            (48.8584, 2.2945, "Eiffel Tower"),
            // San Francisco regular street (should return address)
            (37.7749, -122.4194, "San Francisco Street")
        ]

        // First verify the endpoint format
        verifyEndpointFormat()

        var results: [String] = []

        for (lat, lng, description) in testCoordinates {
            let testCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)

            do {
                let address = try await manager.reverseGeocode(coordinate: testCoordinate)
                results.append("\(description): \(address)")
                print("📍 \(description) -> \(address)")
            } catch {
                results.append("\(description): ERROR - \(error.localizedDescription)")
                print("❌ \(description) -> ERROR: \(error)")
            }
        }

        return results.joined(separator: "\n")
    }

    // MARK: - Target Location Calculation
    func calculateTargetCoordinates(from userLocation: CLLocationCoordinate2D, heading: Double, estimatedDistance: Double) -> CLLocationCoordinate2D {
        // Convert heading from degrees to radians
        let headingRadians = heading * .pi / 180.0

        // Earth's radius in meters
        let earthRadius = 6371000.0

        // Calculate angular distance
        let angularDistance = estimatedDistance / earthRadius

        // Convert user location to radians
        let lat1 = userLocation.latitude * .pi / 180.0
        let lon1 = userLocation.longitude * .pi / 180.0

        // Calculate target latitude
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(headingRadians))

        // Calculate target longitude
        let lon2 = lon1 + atan2(sin(headingRadians) * sin(angularDistance) * cos(lat1),
                               cos(angularDistance) - sin(lat1) * sin(lat2))

        // Convert back to degrees
        let targetLatitude = lat2 * 180.0 / .pi
        let targetLongitude = lon2 * 180.0 / .pi

        return CLLocationCoordinate2D(latitude: targetLatitude, longitude: targetLongitude)
    }

    func estimateTargetDistance(zoomFactor: Double, fieldOfView: Double, objectCoveragePercent: Double = 50.0) -> Double {
        // Enhanced distance estimation based on zoom, field of view, AND object coverage
        // This is crucial: an object covering 20% vs 100% of screen at same zoom = very different distances

        print("🔍 Distance calculation inputs:")
        print("   Zoom Factor: \(String(format: "%.2f", zoomFactor))x")
        print("   Field of View: \(String(format: "%.1f", fieldOfView))°")
        print("   Object Coverage: \(String(format: "%.1f", objectCoveragePercent))% of screen")

        // Adjusted base distance for more realistic results
        let baseDistance = 100.0 // Reduced from 200m to get more realistic distances

        // Zoom multiplier (how far we can see at this zoom level)
        let zoomMultiplier: Double
        if zoomFactor >= 10.0 {
            // Very high zoom (10x+) - adjusted for more realistic distances
            zoomMultiplier = 20.0 + (zoomFactor - 10.0) * 5.0 // Reduced from 30.0
        } else if zoomFactor >= 5.0 {
            // High zoom (5-10x) - can see several miles
            zoomMultiplier = 8.0 + (zoomFactor - 5.0) * 2.4 // Reduced scaling
        } else if zoomFactor >= 2.0 {
            // Medium zoom (2-5x) - progressive increase
            zoomMultiplier = 2.0 + pow(zoomFactor - 2.0, 1.6) * 2.0 // Reduced exponent
        } else {
            // Low zoom (1-2x) - minimal increase
            zoomMultiplier = max(1.0, zoomFactor * 1.5) // Reduced from 2.0
        }

        // Field of view adjustment - narrower FOV means looking further
        let effectiveFOV = max(fieldOfView, 5.0)
        let fovMultiplier = max(0.8, sqrt(68.0 / effectiveFOV))

        // **CRITICAL NEW FACTOR: Object Angular Size Adjustment**
        // If object covers less of the screen, it's much further away
        // If object covers more of the screen, it's much closer
        let referenceCoverage = 50.0 // Reference: object covering 50% of screen
        let coverageRatio = referenceCoverage / max(objectCoveragePercent, 5.0) // Prevent division by very small numbers

        // Angular size physics: distance is inversely proportional to angular size
        // If object covers 20% instead of 50%, it's ~2.5x farther away
        // If object covers 100% instead of 50%, it's ~0.5x closer
        let angularSizeMultiplier = coverageRatio

        let estimatedDistance = baseDistance * zoomMultiplier * fovMultiplier * angularSizeMultiplier

        print("🧮 Distance calculation breakdown:")
        print("   Base Distance: \(String(format: "%.0f", baseDistance))m")
        print("   Zoom Multiplier: \(String(format: "%.2f", zoomMultiplier))")
        print("   FOV Multiplier: \(String(format: "%.2f", fovMultiplier))")
        print("   Angular Size Multiplier: \(String(format: "%.2f", angularSizeMultiplier)) (coverage: \(String(format: "%.1f", objectCoveragePercent))%)")
        print("   Final Distance: \(String(format: "%.0f", estimatedDistance))m (\(String(format: "%.2f", estimatedDistance/1000))km)")
        print("   In Miles: \(String(format: "%.2f", estimatedDistance * 0.000621371)) miles")

        return estimatedDistance
    }

    func lookupTargetAddress(userLocation: CLLocationCoordinate2D, heading: Double, zoomFactor: Double, fieldOfView: Double, objectCoveragePercent: Double = 50.0) async throws -> (currentAddress: String, targetAddress: String, estimatedDistance: Double) {
        // Get current location address
        let currentAddress = try await reverseGeocode(coordinate: userLocation)

        // Calculate target coordinates with object coverage factor
        let estimatedDistance = estimateTargetDistance(zoomFactor: zoomFactor, fieldOfView: fieldOfView, objectCoveragePercent: objectCoveragePercent)
        let targetCoordinates = calculateTargetCoordinates(from: userLocation, heading: heading, estimatedDistance: estimatedDistance)

        // Get target location address
        let targetAddress = try await reverseGeocode(coordinate: targetCoordinates)

        print("🎯 Target calculation:")
        print("📍 User location: \(userLocation)")
        print("🧭 Heading: \(heading)°")
        print("🔍 Zoom: \(String(format: "%.1f", zoomFactor))x, Coverage: \(String(format: "%.1f", objectCoveragePercent))%")
        print("📏 Estimated distance: \(estimatedDistance)m")
        print("🎯 Target coordinates: \(targetCoordinates)")
        print("🏠 Target address: \(targetAddress)")

        return (currentAddress: currentAddress, targetAddress: targetAddress, estimatedDistance: estimatedDistance)
    }

    // MARK: - AI Description Generation (for sharing)
    func generateDescription(prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw APIError.requestCreationFailed
        }

        let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
        let apiKey = "AIzaSyCtMZ-KDXdKlR74MFarqpjSZYllEl-FjhM"

        var request = URLRequest(url: URL(string: "\(geminiEndpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw APIError.responseParsingFailed
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Geocoding Response Models
struct GeocodingResponse: Codable {
    let results: [GeocodingResult]
    let status: String
}

struct GeocodingResult: Codable {
    let address_components: [AddressComponent]
    let formatted_address: String
    let geometry: GeocodingGeometry
    let place_id: String
    let types: [String]
}

struct AddressComponent: Codable {
    let long_name: String
    let short_name: String
    let types: [String]
}

struct GeocodingGeometry: Codable {
    let location: GeocodingLocation
    let location_type: String
}

struct GeocodingLocation: Codable {
    let lat: Double
    let lng: Double
}

// MARK: - API Errors
enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError
    case apiError(String)
    case billingNotEnabled
    case apiNotEnabled
    case apiKeyInvalid
    case quotaExceeded
    case imageProcessingFailed
    case requestCreationFailed
    case responseParsingFailed
}
