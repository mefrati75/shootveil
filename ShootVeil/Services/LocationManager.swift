//
//  LocationManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import CoreLocation
import CoreMotion
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var deviceMotion: CMDeviceMotion?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    
    override init() {
        super.init()
        setupLocationManager()
        setupMotionManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0 // Update every meter
    }
    
    private func setupMotionManager() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1 // 10 Hz
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                if let motion = motion {
                    self?.deviceMotion = motion
                }
            }
        }
        
        isLocationEnabled = true
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
        isLocationEnabled = false
    }
    
    func getCurrentMetadata() -> CaptureMetadata? {
        guard let location = location,
              let heading = heading,
              let deviceMotion = deviceMotion else {
            return nil
        }
        
        let attitude = deviceMotion.attitude
        
        return CaptureMetadata(
            timestamp: Date(),
            gpsCoordinate: location.coordinate,
            altitude: location.altitude,
            heading: heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading,
            pitch: attitude.pitch,
            roll: attitude.roll,
            cameraFocalLength: 4.25, // iPhone camera focal length (approximate)
            imageResolution: CGSize(width: 1920, height: 1080), // Will be updated with actual capture
            accuracy: location.horizontalAccuracy,
            zoomFactor: 1.0, // Default zoom, will be updated by CameraManager
            effectiveFieldOfView: 68.0 // Default FOV, will be updated by CameraManager
        )
    }
    
    // MARK: - Bearing Calculations
    func calculateBearingFromTap(tapPoint: CGPoint, imageSize: CGSize) -> Double? {
        guard let metadata = getCurrentMetadata() else { return nil }
        
        let horizontalFOV = 68.0 // iPhone camera horizontal field of view
        let centerOffset = (tapPoint.x / imageSize.width) - 0.5 // -0.5 to 0.5
        let bearingOffset = centerOffset * horizontalFOV
        
        var targetBearing = metadata.heading + bearingOffset
        
        // Normalize to 0-360 degrees
        if targetBearing < 0 {
            targetBearing += 360
        } else if targetBearing >= 360 {
            targetBearing -= 360
        }
        
        return targetBearing
    }
    
    func calculateDistance(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let currentLocation = location else { return nil }
        return currentLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
} 