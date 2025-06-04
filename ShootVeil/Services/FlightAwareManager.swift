//
//  FlightAwareManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import CoreLocation

class FlightAwareManager {
    static let shared = FlightAwareManager()
    
    // Use centralized API configuration
    private let apiKey = APIConfig.flightAwareAPIKey
    private let baseURL = APIConfig.FlightAwareAPIs.base
    
    private init() {
        print("✈️ FlightAware API initialized with key: \(apiKey.prefix(10))...")
    }
    
    // MARK: - Live Aircraft Search with Cost Control
    func findAircraftInArea(center: CLLocationCoordinate2D, radiusKm: Double = 100, bearing: Double? = nil, tolerance: Double = 15.0) async throws -> [AircraftAPIResponse] {
        
        // Check rate limits before making API call
        guard APIConfig.UsageTracking.canMakeFlightAwareCall() else {
            print("❌ Daily FlightAware API limit reached (\(APIConfig.Settings.maxDailyFlightAwareCalls) calls)")
            throw FlightAwareError.quotaExceeded
        }
        
        guard APIConfig.UsageTracking.canMakeHourlyFlightAwareCall() else {
            print("❌ Hourly FlightAware API limit reached (\(APIConfig.Settings.maxAircraftAPICallsPerHour) calls/hour)")
            throw FlightAwareError.rateLimitExceeded
        }
        
        // Track the API call
        APIConfig.UsageTracking.trackFlightAwareAPICall()
        
        // Convert radius from km to degrees (rough approximation)
        let radiusDegrees = radiusKm / 111.0 // 1 degree ≈ 111 km
        
        // Create bounding box around the center point
        let minLat = center.latitude - radiusDegrees
        let maxLat = center.latitude + radiusDegrees
        let minLon = center.longitude - radiusDegrees
        let maxLon = center.longitude + radiusDegrees
        
        // FlightAware flights/search endpoint
        let endpoint = "\(baseURL)/flights/search/advanced"
        
        // Use the modern FlightAware query format with range operators
        let query = "{range lat \(minLat) \(maxLat)} {range lon \(minLon) \(maxLon)}"
        
        // Query parameters for area search
        let queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "max_pages", value: "1"),
            URLQueryItem(name: "per_page", value: "50")
        ]
        
        guard var urlComponents = URLComponents(string: endpoint) else {
            throw FlightAwareError.invalidURL
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw FlightAwareError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        
        print("🔍 FlightAware API Request: \(url)")
        print("💰 API Usage: \(APIConfig.UsageTracking.getDailyFlightAwareCalls())/\(APIConfig.Settings.maxDailyFlightAwareCalls) daily calls")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlightAwareError.networkError
        }
        
        print("📡 FlightAware Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            throw FlightAwareError.unauthorized
        } else if httpResponse.statusCode == 429 {
            throw FlightAwareError.rateLimitExceeded
        } else if httpResponse.statusCode != 200 {
            // Add debug output for bad requests
            if httpResponse.statusCode == 400 {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("❌ FlightAware 400 Error Response: \(responseString)")
            }
            throw FlightAwareError.apiError(httpResponse.statusCode)
        }
        
        let aircraftList = try parseFlightAwareResponse(data, userLocation: center, bearing: bearing, tolerance: tolerance)
        print("✈️ Found \(aircraftList.count) aircraft in area")
        
        return aircraftList
    }
    
    // MARK: - Get Aircraft Details with Cost Control
    func getAircraftDetails(flightId: String) async throws -> AircraftAPIResponse? {
        // Check rate limits
        guard APIConfig.UsageTracking.canMakeFlightAwareCall() else {
            throw FlightAwareError.quotaExceeded
        }
        
        // Track the API call
        APIConfig.UsageTracking.trackFlightAwareAPICall()
        
        let endpoint = "\(baseURL)/flights/\(flightId)"
        
        guard let url = URL(string: endpoint) else {
            throw FlightAwareError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FlightAwareError.networkError
        }
        
        return try parseFlightDetails(data)
    }
    
    // MARK: - Manual Aircraft Search (User-Initiated)
    func searchAircraftForUser(center: CLLocationCoordinate2D, radiusKm: Double = 100, bearing: Double? = nil, tolerance: Double = 15.0) async throws -> [AircraftAPIResponse] {
        
        print("👤 User-initiated aircraft search")
        print("📍 Location: \(center.latitude), \(center.longitude)")
        print("📏 Radius: \(radiusKm) km")
        if let bearing = bearing {
            print("🧭 Bearing: \(bearing)° (±\(tolerance)°)")
        }
        
        // Check if we have budget for the call
        let dailyCalls = APIConfig.UsageTracking.getDailyFlightAwareCalls()
        let hourlyCalls = APIConfig.UsageTracking.getHourlyFlightAwareCalls()
        
        print("💰 Current usage: \(dailyCalls)/\(APIConfig.Settings.maxDailyFlightAwareCalls) daily, \(hourlyCalls)/\(APIConfig.Settings.maxAircraftAPICallsPerHour) hourly")
        
        if !APIConfig.UsageTracking.canMakeFlightAwareCall() {
            print("❌ Cannot make FlightAware call - daily limit reached")
            throw FlightAwareError.quotaExceeded
        }
        
        if !APIConfig.UsageTracking.canMakeHourlyFlightAwareCall() {
            print("❌ Cannot make FlightAware call - hourly rate limit reached")
            throw FlightAwareError.rateLimitExceeded
        }
        
        return try await findAircraftInArea(center: center, radiusKm: radiusKm, bearing: bearing, tolerance: tolerance)
    }
    
    // MARK: - Response Parsing
    private func parseFlightAwareResponse(_ data: Data, userLocation: CLLocationCoordinate2D, bearing: Double?, tolerance: Double) throws -> [AircraftAPIResponse] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let flights = json["flights"] as? [[String: Any]] else {
            throw FlightAwareError.responseParsingFailed
        }
        
        var aircraftList: [AircraftAPIResponse] = []
        
        for flight in flights {
            if let aircraft = parseFlightData(flight, userLocation: userLocation) {
                // Filter by bearing if specified
                if let targetBearing = bearing {
                    let aircraftBearing = calculateBearing(from: userLocation, to: aircraft.coordinate)
                    let bearingDiff = abs(aircraftBearing - targetBearing)
                    let normalizedDiff = min(bearingDiff, 360 - bearingDiff)
                    
                    if normalizedDiff <= tolerance {
                        aircraftList.append(aircraft)
                    }
                } else {
                    aircraftList.append(aircraft)
                }
            }
        }
        
        // Sort by distance and limit results
        let sortedAircraft = aircraftList.sorted { 
            ($0.coordinate.distance(from: userLocation)) < ($1.coordinate.distance(from: userLocation))
        }
        
        return Array(sortedAircraft.prefix(APIConfig.Settings.maxAircraftResults))
    }
    
    private func parseFlightData(_ flight: [String: Any], userLocation: CLLocationCoordinate2D) -> AircraftAPIResponse? {
        guard let ident = flight["ident"] as? String else { return nil }
        
        // Extract position data
        var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        var altitude: Double = 0
        var groundspeed: Double = 0
        var track: Double = 0
        
        if let lastPosition = flight["last_position"] as? [String: Any] {
            coordinate.latitude = lastPosition["latitude"] as? Double ?? 0
            coordinate.longitude = lastPosition["longitude"] as? Double ?? 0
            altitude = lastPosition["altitude"] as? Double ?? 0
            groundspeed = lastPosition["groundspeed"] as? Double ?? 0
            track = lastPosition["track"] as? Double ?? 0
        }
        
        // Extract aircraft and airline info
        let aircraftType = flight["aircraft_type"] as? String ?? "Unknown"
        let airline = flight["operator"] as? String
        
        // Extract route info
        let origin = flight["origin"] as? [String: Any]
        let destination = flight["destination"] as? [String: Any]
        let originCode = origin?["code_iata"] as? String ?? origin?["code_icao"] as? String
        let destinationCode = destination?["code_iata"] as? String ?? destination?["code_icao"] as? String
        
        return AircraftAPIResponse(
            id: "fa_\(ident)",
            flightNumber: ident,
            aircraftType: aircraftType,
            airline: airline,
            coordinate: coordinate,
            altitude: altitude,
            heading: track,
            speed: groundspeed,
            origin: originCode,
            destination: destinationCode
        )
    }
    
    private func parseFlightDetails(_ data: Data) throws -> AircraftAPIResponse? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FlightAwareError.responseParsingFailed
        }
        
        return parseFlightData(json, userLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    }
    
    // MARK: - Helper Methods
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - Cost Control Utilities
    func getUsageStats() -> (daily: Int, hourly: Int, canCall: Bool) {
        return (
            daily: APIConfig.UsageTracking.getDailyFlightAwareCalls(),
            hourly: APIConfig.UsageTracking.getHourlyFlightAwareCalls(),
            canCall: APIConfig.UsageTracking.canMakeFlightAwareCall() && APIConfig.UsageTracking.canMakeHourlyFlightAwareCall()
        )
    }
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D {
    func distance(from: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - FlightAware Errors
enum FlightAwareError: Error, LocalizedError {
    case invalidURL
    case networkError
    case unauthorized
    case apiError(Int)
    case responseParsingFailed
    case noDataAvailable
    case quotaExceeded
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid FlightAware API URL"
        case .networkError:
            return "FlightAware network request failed"
        case .unauthorized:
            return "FlightAware API key unauthorized"
        case .apiError(let code):
            return "FlightAware API error: \(code)"
        case .responseParsingFailed:
            return "Failed to parse FlightAware response"
        case .noDataAvailable:
            return "No flight data available"
        case .quotaExceeded:
            return "Daily FlightAware API quota exceeded"
        case .rateLimitExceeded:
            return "FlightAware API rate limit exceeded"
        }
    }
} 