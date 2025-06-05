//
//  UnvealCalculator.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/3/25.
//

import Foundation
import CoreLocation
import UIKit

// MARK: - Unveal v1.0 - Smart Location Calculator
class UnvealCalculator: ObservableObject {
    static let shared = UnvealCalculator()

    @Published var isCollectingFeedback = false
    @Published var feedbackItems: [UnvealFeedbackItem] = []

    private let logFileName = "unveal_log_v1.0.json"
    private let version = "1.0"

    private init() {
        loadFeedbackLog()
    }

    // MARK: - Unveal v1.0 Core Calculation Function
    func calculateTargetLocation(
        userLocation: CLLocationCoordinate2D,
        heading: Double,
        distance: Double,
        zoomFactor: Double,
        fieldOfView: Double,
        altitude: Double,
        deviceOrientation: String,
        timestamp: Date
    ) -> UnvealResult {

        print("🧠 Unveal v1.0: Starting location calculation")
        print("📍 User: \(userLocation.latitude), \(userLocation.longitude)")
        print("🧭 Heading: \(heading)°")
        print("📏 Distance: \(distance)m")
        print("🔍 Zoom: \(zoomFactor)x")

        // Core Unveal v1.0 Algorithm
        let calculation = UnvealCalculation(
            userLocation: userLocation,
            heading: heading,
            estimatedDistance: distance,
            zoomFactor: zoomFactor,
            fieldOfView: fieldOfView,
            altitude: altitude,
            deviceOrientation: deviceOrientation,
            timestamp: timestamp,
            version: version
        )

        // Calculate target coordinates using bearing and distance
        let targetCoordinates = calculateTargetCoordinates(
            from: userLocation,
            bearing: heading,
            distance: distance
        )

        // Calculate confidence based on multiple factors
        let confidence = calculateConfidence(
            distance: distance,
            zoomFactor: zoomFactor,
            altitude: altitude,
            fieldOfView: fieldOfView
        )

        // Create result
        let result = UnvealResult(
            id: UUID(),
            calculation: calculation,
            targetCoordinates: targetCoordinates,
            confidence: confidence,
            calculationMethod: "bearing_distance_v1.0",
            metadata: createCalculationMetadata(
                distance: distance,
                zoomFactor: zoomFactor,
                confidence: confidence
            )
        )

        print("✅ Unveal v1.0 Result:")
        print("🎯 Target: \(targetCoordinates.latitude), \(targetCoordinates.longitude)")
        print("📊 Confidence: \(String(format: "%.1f", confidence * 100))%")

        return result
    }

    // MARK: - Advanced Calculation Methods
    private func calculateTargetCoordinates(
        from userLocation: CLLocationCoordinate2D,
        bearing: Double,
        distance: Double
    ) -> CLLocationCoordinate2D {

        // Convert bearing to radians
        let bearingRadians = bearing * .pi / 180.0

        // Earth's radius in meters
        let earthRadius = 6371000.0

        // Calculate angular distance
        let angularDistance = distance / earthRadius

        // Convert user location to radians
        let lat1 = userLocation.latitude * .pi / 180.0
        let lon1 = userLocation.longitude * .pi / 180.0

        // Calculate target latitude
        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearingRadians)
        )

        // Calculate target longitude
        let lon2 = lon1 + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        // Convert back to degrees
        let targetLatitude = lat2 * 180.0 / .pi
        let targetLongitude = lon2 * 180.0 / .pi

        return CLLocationCoordinate2D(
            latitude: targetLatitude,
            longitude: targetLongitude
        )
    }

    private func calculateConfidence(
        distance: Double,
        zoomFactor: Double,
        altitude: Double,
        fieldOfView: Double
    ) -> Double {

        var confidence = 1.0

        // Distance factor (closer = more confident)
        if distance > 1000 {
            confidence *= 0.7 // Long distance reduces confidence
        } else if distance > 500 {
            confidence *= 0.85
        } else if distance > 100 {
            confidence *= 0.95
        }

        // Zoom factor (higher zoom = more precise)
        if zoomFactor > 3.0 {
            confidence *= 1.1 // High zoom increases confidence
        } else if zoomFactor > 2.0 {
            confidence *= 1.05
        }

        // Altitude factor (higher altitude = wider view)
        if altitude > 100 {
            confidence *= 0.9 // High altitude reduces precision
        }

        // Field of view factor
        if fieldOfView < 30 {
            confidence *= 1.1 // Narrow FOV = more precise
        } else if fieldOfView > 60 {
            confidence *= 0.9 // Wide FOV = less precise
        }

        return min(confidence, 1.0) // Cap at 100%
    }

    private func createCalculationMetadata(
        distance: Double,
        zoomFactor: Double,
        confidence: Double
    ) -> [String: Any] {
        return [
            "algorithm_version": version,
            "distance_estimate": distance,
            "zoom_factor": zoomFactor,
            "confidence_score": confidence,
            "calculation_timestamp": Date().timeIntervalSince1970,
            "method": "trigonometric_bearing_calculation"
        ]
    }

    // MARK: - Feedback Collection System
    func collectUserFeedback(
        for result: UnvealResult,
        actualLocation: CLLocationCoordinate2D,
        actualName: String,
        userNotes: String? = nil
    ) {

        let feedbackItem = UnvealFeedbackItem(
            id: UUID(),
            unvealResultId: result.id,
            originalCalculation: result.calculation,
            calculatedLocation: result.targetCoordinates,
            actualLocation: actualLocation,
            actualName: actualName,
            userNotes: userNotes,
            accuracy: calculateAccuracy(
                calculated: result.targetCoordinates,
                actual: actualLocation
            ),
            timestamp: Date()
        )

        feedbackItems.append(feedbackItem)
        saveFeedbackLog()

        print("📝 Feedback collected:")
        print("🎯 Calculated: \(result.targetCoordinates)")
        print("✅ Actual: \(actualLocation)")
        print("📏 Error: \(String(format: "%.1f", feedbackItem.accuracy))m")
        print("💾 Saved to unveal log v1.0")
    }

    private func calculateAccuracy(
        calculated: CLLocationCoordinate2D,
        actual: CLLocationCoordinate2D
    ) -> Double {

        let calculatedLocation = CLLocation(
            latitude: calculated.latitude,
            longitude: calculated.longitude
        )

        let actualLocation = CLLocation(
            latitude: actual.latitude,
            longitude: actual.longitude
        )

        return calculatedLocation.distance(from: actualLocation)
    }

    // MARK: - Data Persistence for ML Training
    private func saveFeedbackLog() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(feedbackItems)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logPath = documentsPath.appendingPathComponent(logFileName)

            try data.write(to: logPath)

            print("💾 Unveal log v1.0 saved: \(feedbackItems.count) items")
        } catch {
            print("❌ Failed to save unveal log: \(error)")
        }
    }

    private func loadFeedbackLog() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logPath = documentsPath.appendingPathComponent(logFileName)

            guard FileManager.default.fileExists(atPath: logPath.path) else {
                print("📂 No existing unveal log found")
                return
            }

            let data = try Data(contentsOf: logPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            feedbackItems = try decoder.decode([UnvealFeedbackItem].self, from: data)

            print("📖 Loaded unveal log v1.0: \(feedbackItems.count) items")
        } catch {
            print("❌ Failed to load unveal log: \(error)")
            feedbackItems = []
        }
    }

    // MARK: - ML Training Data Export
    func exportTrainingData() -> UnvealTrainingDataset {
        let dataset = UnvealTrainingDataset(
            version: version,
            totalSamples: feedbackItems.count,
            averageAccuracy: feedbackItems.map { $0.accuracy }.reduce(0, +) / Double(feedbackItems.count),
            feedbackItems: feedbackItems,
            exportDate: Date()
        )

        print("📊 Training dataset prepared: \(dataset.totalSamples) samples")
        print("📈 Average accuracy: \(String(format: "%.1f", dataset.averageAccuracy))m")

        return dataset
    }

    // MARK: - Analytics and Insights
    func getCalculationAnalytics() -> UnvealAnalytics {
        guard !feedbackItems.isEmpty else {
            return UnvealAnalytics(
                totalCalculations: 0,
                averageAccuracy: 0,
                bestAccuracy: 0,
                worstAccuracy: 0,
                accuracyImprovement: 0,
                confidenceCorrelation: 0
            )
        }

        let accuracies = feedbackItems.map { $0.accuracy }
        let bestAccuracy = accuracies.min() ?? 0
        let worstAccuracy = accuracies.max() ?? 0
        let averageAccuracy = accuracies.reduce(0, +) / Double(accuracies.count)

        return UnvealAnalytics(
            totalCalculations: feedbackItems.count,
            averageAccuracy: averageAccuracy,
            bestAccuracy: bestAccuracy,
            worstAccuracy: worstAccuracy,
            accuracyImprovement: calculateAccuracyImprovement(),
            confidenceCorrelation: calculateConfidenceCorrelation()
        )
    }

    private func calculateAccuracyImprovement() -> Double {
        guard feedbackItems.count > 10 else { return 0 }

        let firstHalf = Array(feedbackItems.prefix(feedbackItems.count / 2))
        let secondHalf = Array(feedbackItems.suffix(feedbackItems.count / 2))

        let firstAverage = firstHalf.map { $0.accuracy }.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.map { $0.accuracy }.reduce(0, +) / Double(secondHalf.count)

        return firstAverage - secondAverage // Positive = improvement
    }

    private func calculateConfidenceCorrelation() -> Double {
        // Calculate correlation between confidence and accuracy
        // This would be more complex in a real implementation
        return 0.75 // Placeholder
    }
}

// MARK: - Data Models for Unveal v1.0

struct UnvealCalculation: Codable {
    let userLocation: CLLocationCoordinate2D
    let heading: Double
    let estimatedDistance: Double
    let zoomFactor: Double
    let fieldOfView: Double
    let altitude: Double
    let deviceOrientation: String
    let timestamp: Date
    let version: String
}

struct UnvealResult {
    let id: UUID
    let calculation: UnvealCalculation
    let targetCoordinates: CLLocationCoordinate2D
    let confidence: Double
    let calculationMethod: String
    let metadata: [String: Any]
}

struct UnvealFeedbackItem: Codable, Identifiable {
    let id: UUID
    let unvealResultId: UUID
    let originalCalculation: UnvealCalculation
    let calculatedLocation: CLLocationCoordinate2D
    let actualLocation: CLLocationCoordinate2D
    let actualName: String
    let userNotes: String?
    let accuracy: Double // Distance error in meters
    let timestamp: Date
}

struct UnvealTrainingDataset: Codable {
    let version: String
    let totalSamples: Int
    let averageAccuracy: Double
    let feedbackItems: [UnvealFeedbackItem]
    let exportDate: Date
}

struct UnvealAnalytics {
    let totalCalculations: Int
    let averageAccuracy: Double
    let bestAccuracy: Double
    let worstAccuracy: Double
    let accuracyImprovement: Double
    let confidenceCorrelation: Double
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: lat, longitude: lon)
    }

    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}
