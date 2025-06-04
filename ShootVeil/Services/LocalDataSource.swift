//
//  LocalDataSource.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import CoreLocation

class LocalDataSource {

    // MARK: - Sample Buildings & Landmarks Data
    static let sampleBuildings: [BuildingAPIResponse] = [
        // San Francisco
        BuildingAPIResponse(
            id: "sf_transamerica",
            name: "Transamerica Pyramid",
            coordinate: CLLocationCoordinate2D(latitude: 37.7952, longitude: -122.4028),
            height: 260,
            type: .landmark,
            description: "A 48-story futurist skyscraper and the second-tallest building in San Francisco.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Transamerica_Pyramid",
            constructionYear: 1972
        ),
        BuildingAPIResponse(
            id: "sf_salesforce",
            name: "Salesforce Tower",
            coordinate: CLLocationCoordinate2D(latitude: 37.7895, longitude: -122.3973),
            height: 326,
            type: .office,
            description: "The tallest building in San Francisco.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Salesforce_Tower",
            constructionYear: 2018
        ),
        BuildingAPIResponse(
            id: "sf_coit_tower",
            name: "Coit Tower",
            coordinate: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4058),
            height: 64,
            type: .landmark,
            description: "A 210-foot tower built in 1933 on Telegraph Hill in San Francisco.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Coit_Tower",
            constructionYear: 1933
        ),
        BuildingAPIResponse(
            id: "sf_golden_gate",
            name: "Golden Gate Bridge",
            coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
            height: 227,
            type: .landmark,
            description: "Iconic suspension bridge spanning the Golden Gate strait.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Golden_Gate_Bridge",
            constructionYear: 1937
        ),

        // New York
        BuildingAPIResponse(
            id: "ny_empire_state",
            name: "Empire State Building",
            coordinate: CLLocationCoordinate2D(latitude: 40.7484, longitude: -73.9857),
            height: 443,
            type: .landmark,
            description: "A 102-story Art Deco skyscraper in Midtown Manhattan.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Empire_State_Building",
            constructionYear: 1931
        ),
        BuildingAPIResponse(
            id: "ny_one_wtc",
            name: "One World Trade Center",
            coordinate: CLLocationCoordinate2D(latitude: 40.7127, longitude: -74.0134),
            height: 541,
            type: .office,
            description: "The main building of the rebuilt World Trade Center complex.",
            wikipediaURL: "https://en.wikipedia.org/wiki/One_World_Trade_Center",
            constructionYear: 2014
        ),
        BuildingAPIResponse(
            id: "ny_statue_liberty",
            name: "Statue of Liberty",
            coordinate: CLLocationCoordinate2D(latitude: 40.6892, longitude: -74.0445),
            height: 93,
            type: .landmark,
            description: "A colossal neoclassical sculpture on Liberty Island in New York Harbor.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Statue_of_Liberty",
            constructionYear: 1886
        ),

        // Los Angeles
        BuildingAPIResponse(
            id: "la_hollywood_sign",
            name: "Hollywood Sign",
            coordinate: CLLocationCoordinate2D(latitude: 34.1341, longitude: -118.3217),
            height: 13,
            type: .landmark,
            description: "Iconic landmark and American cultural icon located on Mount Lee.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Hollywood_Sign",
            constructionYear: 1923
        ),
        BuildingAPIResponse(
            id: "la_us_bank_tower",
            name: "U.S. Bank Tower",
            coordinate: CLLocationCoordinate2D(latitude: 34.0512, longitude: -118.2571),
            height: 310,
            type: .office,
            description: "A 73-story skyscraper in downtown Los Angeles.",
            wikipediaURL: "https://en.wikipedia.org/wiki/U.S._Bank_Tower_(Los_Angeles)",
            constructionYear: 1989
        ),

        // Washington DC
        BuildingAPIResponse(
            id: "dc_washington_monument",
            name: "Washington Monument",
            coordinate: CLLocationCoordinate2D(latitude: 38.8895, longitude: -77.0353),
            height: 169,
            type: .landmark,
            description: "An obelisk on the National Mall built to commemorate George Washington.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Washington_Monument",
            constructionYear: 1884
        ),
        BuildingAPIResponse(
            id: "dc_capitol",
            name: "U.S. Capitol",
            coordinate: CLLocationCoordinate2D(latitude: 38.8899, longitude: -77.0091),
            height: 88,
            type: .government,
            description: "The meeting place of the United States Congress.",
            wikipediaURL: "https://en.wikipedia.org/wiki/United_States_Capitol",
            constructionYear: 1800
        ),

        // Chicago
        BuildingAPIResponse(
            id: "chicago_willis",
            name: "Willis Tower",
            coordinate: CLLocationCoordinate2D(latitude: 41.8789, longitude: -87.6359),
            height: 442,
            type: .office,
            description: "A 110-story skyscraper, formerly known as Sears Tower.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Willis_Tower",
            constructionYear: 1973
        ),

        // Seattle
        BuildingAPIResponse(
            id: "seattle_space_needle",
            name: "Space Needle",
            coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493),
            height: 184,
            type: .landmark,
            description: "An observation tower built for the 1962 World's Fair.",
            wikipediaURL: "https://en.wikipedia.org/wiki/Space_Needle",
            constructionYear: 1962
        )
    ]

    // MARK: - Sample Aircraft Data
    static let sampleAircraft: [AircraftAPIResponse] = [
        AircraftAPIResponse(
            id: "aircraft_aa123",
            flightNumber: "AA123",
            aircraftType: "Boeing 737-800",
            airline: "American Airlines",
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            altitude: 35000,
            heading: 45,
            speed: 520,
            origin: "SFO",
            destination: "LAX"
        ),
        AircraftAPIResponse(
            id: "aircraft_ua456",
            flightNumber: "UA456",
            aircraftType: "Airbus A320",
            airline: "United Airlines",
            coordinate: CLLocationCoordinate2D(latitude: 37.7950, longitude: -122.4100),
            altitude: 28000,
            heading: 90,
            speed: 480,
            origin: "SFO",
            destination: "DEN"
        ),
        AircraftAPIResponse(
            id: "aircraft_dl789",
            flightNumber: "DL789",
            aircraftType: "Boeing 777-200",
            airline: "Delta Air Lines",
            coordinate: CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4200),
            altitude: 41000,
            heading: 180,
            speed: 550,
            origin: "SFO",
            destination: "JFK"
        ),
        AircraftAPIResponse(
            id: "aircraft_sw101",
            flightNumber: "WN101",
            aircraftType: "Boeing 737-700",
            airline: "Southwest Airlines",
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4000),
            altitude: 32000,
            heading: 270,
            speed: 490,
            origin: "SFO",
            destination: "PHX"
        ),
        AircraftAPIResponse(
            id: "aircraft_ba208",
            flightNumber: "BA208",
            aircraftType: "Boeing 787-9",
            airline: "British Airways",
            coordinate: CLLocationCoordinate2D(latitude: 37.7900, longitude: -122.4300),
            altitude: 39000,
            heading: 60,
            speed: 580,
            origin: "SFO",
            destination: "LHR"
        ),
        AircraftAPIResponse(
            id: "aircraft_lufthansa",
            flightNumber: "LH441",
            aircraftType: "Airbus A340-600",
            airline: "Lufthansa",
            coordinate: CLLocationCoordinate2D(latitude: 37.7850, longitude: -122.4150),
            altitude: 37000,
            heading: 30,
            speed: 560,
            origin: "SFO",
            destination: "FRA"
        ),
        AircraftAPIResponse(
            id: "aircraft_police_helo",
            flightNumber: nil,
            aircraftType: "Bell 206",
            airline: "SFPD",
            coordinate: CLLocationCoordinate2D(latitude: 37.7900, longitude: -122.4050),
            altitude: 1500,
            heading: 120,
            speed: 85,
            origin: nil,
            destination: nil
        ),
        AircraftAPIResponse(
            id: "aircraft_news_helo",
            flightNumber: "N123TV",
            aircraftType: "Eurocopter AS350",
            airline: "News Helicopter",
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4250),
            altitude: 2000,
            heading: 200,
            speed: 95,
            origin: nil,
            destination: nil
        )
    ]

    // MARK: - Data Access Methods
    static func getBuildings(near location: CLLocationCoordinate2D, within radiusKm: Double = 50) -> [BuildingAPIResponse] {
        return sampleBuildings.filter { building in
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: building.coordinate.latitude, longitude: building.coordinate.longitude))
            return distance <= (radiusKm * 1000) // Convert km to meters
        }
    }

    static func getAircraft(near location: CLLocationCoordinate2D, within radiusKm: Double = 100) -> [AircraftAPIResponse] {
        return sampleAircraft.filter { aircraft in
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: aircraft.coordinate.latitude, longitude: aircraft.coordinate.longitude))
            return distance <= (radiusKm * 1000) // Convert km to meters
        }
    }

    static func getBuildingsByBearing(from location: CLLocationCoordinate2D, bearing: Double, tolerance: Double = 5.0, radiusKm: Double = 20) -> [BuildingAPIResponse] {
        let nearbyBuildings = getBuildings(near: location, within: radiusKm)

        return nearbyBuildings.filter { building in
            let buildingBearing = calculateBearing(from: location, to: building.coordinate)
            let bearingDiff = abs(buildingBearing - bearing)
            let normalizedDiff = min(bearingDiff, 360 - bearingDiff)
            return normalizedDiff <= tolerance
        }
    }

    static func getAircraftByBearing(from location: CLLocationCoordinate2D, bearing: Double, tolerance: Double = 10.0, radiusKm: Double = 100) -> [AircraftAPIResponse] {
        let nearbyAircraft = getAircraft(near: location, within: radiusKm)

        return nearbyAircraft.filter { aircraft in
            let aircraftBearing = calculateBearing(from: location, to: aircraft.coordinate)
            let bearingDiff = abs(aircraftBearing - bearing)
            let normalizedDiff = min(bearingDiff, 360 - bearingDiff)
            return normalizedDiff <= tolerance
        }
    }

    // MARK: - Helper Methods
    private static func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
