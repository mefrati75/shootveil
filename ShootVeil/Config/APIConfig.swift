//
//  APIConfig.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation

struct APIConfig {

    // MARK: - Google API Configuration
    static let googleAPIKey = "AIzaSyCtMZ-KDXdKlR74MFarqpjSZYllEl-FjhM"

    // MARK: - FlightAware API Configuration
    static let flightAwareAPIKey = "Hn8TKMPzAfm82IcWR7W0UHDbJyoQPFdA"

    // MARK: - API Endpoints
    struct GoogleAPIs {
        static let geminiVision = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent"
        static let geocoding = "https://maps.googleapis.com/maps/api/geocode/json"
        static let places = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        static let placeDetails = "https://maps.googleapis.com/maps/api/place/details/json"
    }

    struct FlightAwareAPIs {
        static let base = "https://aeroapi.flightaware.com/aeroapi"
        static let flightSearch = "\(base)/flights/search/advanced"
        static let flightDetails = "\(base)/flights"
        static let aircraftSearch = "\(base)/aircraft/search"
    }

    // MARK: - API Settings
    struct Settings {
        // Google APIs
        static let geminiEnabled = true
        static let placesAPIEnabled = true

        // FlightAware API - Cost Control
        static let flightAwareEnabled = true
        static let automaticAircraftIdentification = false  // Changed to manual only
        static let maxAircraftAPICallsPerHour = 10  // Rate limiting

        // Fallback options
        static let localDataFallback = true

        // Request timeouts (seconds)
        static let geminiTimeout: TimeInterval = 30.0
        static let placesTimeout: TimeInterval = 10.0
        static let flightAwareTimeout: TimeInterval = 15.0

        // Search parameters
        static let maxBuildingResults = 5
        static let maxAircraftResults = 8  // Increased for better selection
        static let placesSearchRadius = 2000 // meters
        static let aircraftSearchRadius = 100 // kilometers

        // Bearing tolerances (degrees)
        static let aircraftBearingTolerance = 15.0
        static let buildingBearingTolerance = 8.0
        static let placesBearingTolerance = 15.0

        // Cost Control Settings
        static let enableAPIUsageTracking = true
        static let warnOnHighAPIUsage = true
        static let maxDailyFlightAwareCalls = 100
    }

    // MARK: - API Usage Tracking
    struct UsageTracking {
        private static let userDefaults = UserDefaults.standard
        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        static func trackFlightAwareAPICall() {
            let today = dateFormatter.string(from: Date())
            let key = "flightaware_calls_\(today)"
            let currentCalls = userDefaults.integer(forKey: key)
            userDefaults.set(currentCalls + 1, forKey: key)

            print("📊 FlightAware API calls today: \(currentCalls + 1)/\(Settings.maxDailyFlightAwareCalls)")

            if Settings.warnOnHighAPIUsage && currentCalls + 1 > Settings.maxDailyFlightAwareCalls * 8 / 10 {
                print("⚠️ Warning: Approaching daily FlightAware API limit")
            }
        }

        static func getDailyFlightAwareCalls() -> Int {
            let today = dateFormatter.string(from: Date())
            let key = "flightaware_calls_\(today)"
            return userDefaults.integer(forKey: key)
        }

        static func canMakeFlightAwareCall() -> Bool {
            let dailyCalls = getDailyFlightAwareCalls()
            return dailyCalls < Settings.maxDailyFlightAwareCalls
        }

        static func getHourlyFlightAwareCalls() -> Int {
            let hour = Calendar.current.component(.hour, from: Date())
            let today = dateFormatter.string(from: Date())
            let key = "flightaware_calls_\(today)_\(hour)"
            return userDefaults.integer(forKey: key)
        }

        static func canMakeHourlyFlightAwareCall() -> Bool {
            let hourlyCalls = getHourlyFlightAwareCalls()
            return hourlyCalls < Settings.maxAircraftAPICallsPerHour
        }
    }

    // MARK: - Required APIs Check
    static var requiredGoogleAPIs: [String] {
        return [
            "Generative Language API (for Gemini)",
            "Places API",
            "Geocoding API"
        ]
    }

    static var flightAwareInfo: [String] {
        return [
            "FlightAware AeroAPI subscription required",
            "Real-time flight tracking worldwide",
            "Sign up at: https://flightaware.com/commercial/aeroapi/",
            "💰 Cost-controlled: Manual aircraft identification only",
            "📊 Usage tracking enabled to prevent overages"
        ]
    }

    // MARK: - API Status
    static func checkAPIStatus() {
        print("🔑 ShootVeil API Configuration")
        print("═══════════════════════════════")

        // Google APIs
        print("🌐 Google APIs:")
        print("   API Key: \(googleAPIKey.prefix(10))...")
        print("   Gemini Enabled: \(Settings.geminiEnabled)")
        print("   Places API Enabled: \(Settings.placesAPIEnabled)")
        print("")

        // FlightAware API with cost control info
        print("✈️ FlightAware API:")
        print("   API Key: \(flightAwareAPIKey.prefix(10))...")
        print("   FlightAware Enabled: \(Settings.flightAwareEnabled)")
        print("   Automatic Identification: \(Settings.automaticAircraftIdentification ? "ON (💰 Costly)" : "OFF (💚 Cost-Controlled)")")
        print("   Daily API Calls: \(UsageTracking.getDailyFlightAwareCalls())/\(Settings.maxDailyFlightAwareCalls)")
        print("   Hourly Rate Limit: \(Settings.maxAircraftAPICallsPerHour) calls/hour")
        print("")

        // Fallback
        print("📍 Fallback Options:")
        print("   Local Data Fallback: \(Settings.localDataFallback)")
        print("")

        print("📋 Required Google APIs to enable:")
        for api in requiredGoogleAPIs {
            print("   • \(api)")
        }
        print("🔗 Enable at: https://console.cloud.google.com/apis/library")
        print("")

        print("📋 FlightAware API Info:")
        for info in flightAwareInfo {
            print("   • \(info)")
        }
        print("")

        // Cost control summary
        print("💰 Cost Control Summary:")
        print("   • Aircraft identification: User-initiated only")
        print("   • API usage tracking: \(Settings.enableAPIUsageTracking ? "Enabled" : "Disabled")")
        print("   • Daily limit warnings: \(Settings.warnOnHighAPIUsage ? "Enabled" : "Disabled")")
        print("   • Can make FlightAware call: \(UsageTracking.canMakeFlightAwareCall() ? "✅ Yes" : "❌ Daily limit reached")")
        print("")
    }

    // MARK: - Data Source Priority
    enum DataSourcePriority {
        case realTimeAPI    // FlightAware for aircraft, Google for buildings
        case localData      // Pre-loaded sample data
        case hybrid         // Combination of both
    }

    static var currentDataSourceStrategy: DataSourcePriority {
        if Settings.flightAwareEnabled && Settings.geminiEnabled {
            return .realTimeAPI
        } else if Settings.localDataFallback {
            return .hybrid
        } else {
            return .localData
        }
    }
}
