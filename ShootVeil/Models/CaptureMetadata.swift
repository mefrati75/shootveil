//
//  CaptureMetadata.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import CoreLocation

struct CaptureMetadata: Codable {
    let timestamp: Date
    let gpsCoordinate: CLLocationCoordinate2D
    let altitude: Double // meters above sea level
    let heading: Double // compass bearing (0-360°)
    let pitch: Double // device tilt angle
    let roll: Double // device rotation angle
    let cameraFocalLength: Float
    let imageResolution: CGSize
    let accuracy: CLLocationAccuracy
    let zoomFactor: CGFloat // camera zoom level
    let effectiveFieldOfView: Double // horizontal field of view in degrees considering zoom
    
    // Custom encoding/decoding for CLLocationCoordinate2D and CGSize
    enum CodingKeys: String, CodingKey {
        case timestamp, altitude, heading, pitch, roll, cameraFocalLength, accuracy, zoomFactor, effectiveFieldOfView
        case latitude, longitude, width, height
    }
    
    init(
        timestamp: Date,
        gpsCoordinate: CLLocationCoordinate2D,
        altitude: Double,
        heading: Double,
        pitch: Double,
        roll: Double,
        cameraFocalLength: Float,
        imageResolution: CGSize,
        accuracy: CLLocationAccuracy,
        zoomFactor: CGFloat,
        effectiveFieldOfView: Double
    ) {
        self.timestamp = timestamp
        self.gpsCoordinate = gpsCoordinate
        self.altitude = altitude
        self.heading = heading
        self.pitch = pitch
        self.roll = roll
        self.cameraFocalLength = cameraFocalLength
        self.imageResolution = imageResolution
        self.accuracy = accuracy
        self.zoomFactor = zoomFactor
        self.effectiveFieldOfView = effectiveFieldOfView
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(gpsCoordinate.latitude, forKey: .latitude)
        try container.encode(gpsCoordinate.longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(heading, forKey: .heading)
        try container.encode(pitch, forKey: .pitch)
        try container.encode(roll, forKey: .roll)
        try container.encode(cameraFocalLength, forKey: .cameraFocalLength)
        try container.encode(imageResolution.width, forKey: .width)
        try container.encode(imageResolution.height, forKey: .height)
        try container.encode(accuracy, forKey: .accuracy)
        try container.encode(zoomFactor, forKey: .zoomFactor)
        try container.encode(effectiveFieldOfView, forKey: .effectiveFieldOfView)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        gpsCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        altitude = try container.decode(Double.self, forKey: .altitude)
        heading = try container.decode(Double.self, forKey: .heading)
        pitch = try container.decode(Double.self, forKey: .pitch)
        roll = try container.decode(Double.self, forKey: .roll)
        cameraFocalLength = try container.decode(Float.self, forKey: .cameraFocalLength)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        imageResolution = CGSize(width: width, height: height)
        accuracy = try container.decode(CLLocationAccuracy.self, forKey: .accuracy)
        zoomFactor = try container.decode(CGFloat.self, forKey: .zoomFactor)
        effectiveFieldOfView = try container.decode(Double.self, forKey: .effectiveFieldOfView)
    }
}

// MARK: - Building Data Model
struct Building: Codable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let height: Double // meters
    let type: BuildingType
    let description: String
    let wikipediaURL: String?
    let constructionYear: Int?
    let distance: Double? // calculated distance from user
    let address: String? // reverse geocoded address
    let isLandmark: Bool // whether this is a famous landmark
    let landmarkCategory: LandmarkCategory? // type of landmark
    
    // Custom encoding/decoding for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, height, type, description, wikipediaURL, constructionYear, distance, address, isLandmark, landmarkCategory
        case latitude, longitude
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(height, forKey: .height)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(wikipediaURL, forKey: .wikipediaURL)
        try container.encodeIfPresent(constructionYear, forKey: .constructionYear)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(isLandmark, forKey: .isLandmark)
        try container.encodeIfPresent(landmarkCategory, forKey: .landmarkCategory)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        height = try container.decode(Double.self, forKey: .height)
        type = try container.decode(BuildingType.self, forKey: .type)
        description = try container.decode(String.self, forKey: .description)
        wikipediaURL = try container.decodeIfPresent(String.self, forKey: .wikipediaURL)
        constructionYear = try container.decodeIfPresent(Int.self, forKey: .constructionYear)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        isLandmark = try container.decode(Bool.self, forKey: .isLandmark)
        landmarkCategory = try container.decodeIfPresent(LandmarkCategory.self, forKey: .landmarkCategory)
    }
    
    // Regular initializer
    init(
        id: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        height: Double,
        type: BuildingType,
        description: String,
        wikipediaURL: String? = nil,
        constructionYear: Int? = nil,
        distance: Double? = nil,
        address: String? = nil,
        isLandmark: Bool = false,
        landmarkCategory: LandmarkCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.height = height
        self.type = type
        self.description = description
        self.wikipediaURL = wikipediaURL
        self.constructionYear = constructionYear
        self.distance = distance
        self.address = address
        self.isLandmark = isLandmark
        self.landmarkCategory = landmarkCategory
    }
}

enum BuildingType: String, CaseIterable, Codable {
    case landmark = "landmark"
    case office = "office"
    case residential = "residential"
    case commercial = "commercial"
    case government = "government"
    case religious = "religious"
    case educational = "educational"
    case industrial = "industrial"
    case other = "other"
}

enum LandmarkCategory: String, CaseIterable, Codable {
    case historicalSite = "Historical Site"
    case religiousBuilding = "Religious Building"
    case government = "Government Building"
    case monument = "Monument"
    case culturalSite = "Cultural Site"
    case touristAttraction = "Tourist Attraction"
    case architecture = "Architectural Landmark"
    case bridge = "Bridge"
    case tower = "Tower"
    case museum = "Museum"
}

// MARK: - Aircraft Data Model
struct Aircraft: Codable {
    let id: String
    let flightNumber: String?
    let aircraftType: String
    let airline: String?
    let coordinate: CLLocationCoordinate2D
    let altitude: Double // feet
    let heading: Double // bearing
    let speed: Double // knots
    let origin: String?
    let destination: String?
    let distance: Double? // calculated distance from user
    
    // Custom encoding/decoding for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, flightNumber, aircraftType, airline, altitude, heading, speed, origin, destination, distance
        case latitude, longitude
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(flightNumber, forKey: .flightNumber)
        try container.encode(aircraftType, forKey: .aircraftType)
        try container.encodeIfPresent(airline, forKey: .airline)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(heading, forKey: .heading)
        try container.encode(speed, forKey: .speed)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(destination, forKey: .destination)
        try container.encodeIfPresent(distance, forKey: .distance)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        flightNumber = try container.decodeIfPresent(String.self, forKey: .flightNumber)
        aircraftType = try container.decode(String.self, forKey: .aircraftType)
        airline = try container.decodeIfPresent(String.self, forKey: .airline)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        altitude = try container.decode(Double.self, forKey: .altitude)
        heading = try container.decode(Double.self, forKey: .heading)
        speed = try container.decode(Double.self, forKey: .speed)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        destination = try container.decodeIfPresent(String.self, forKey: .destination)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
    }
    
    // Regular initializer
    init(
        id: String,
        flightNumber: String? = nil,
        aircraftType: String,
        airline: String? = nil,
        coordinate: CLLocationCoordinate2D,
        altitude: Double,
        heading: Double,
        speed: Double,
        origin: String? = nil,
        destination: String? = nil,
        distance: Double? = nil
    ) {
        self.id = id
        self.flightNumber = flightNumber
        self.aircraftType = aircraftType
        self.airline = airline
        self.coordinate = coordinate
        self.altitude = altitude
        self.heading = heading
        self.speed = speed
        self.origin = origin
        self.destination = destination
        self.distance = distance
    }
}

// MARK: - Identification Result
struct IdentificationResult {
    let id: String
    let type: ObjectType
    let confidence: Double
    let name: String
    let description: String
    let distance: Double?
    let additionalInfo: [String: Any]
    let timestamp: Date
}

enum ObjectType: String, CaseIterable {
    case building = "building"
    case landmark = "landmark"
    case aircraft = "aircraft"
    case unknown = "unknown"
} 