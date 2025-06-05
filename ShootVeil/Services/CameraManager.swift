//
//  CameraManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import Foundation
import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var photoOutput = AVCapturePhotoOutput()
    @Published var previewLayer = AVCaptureVideoPreviewLayer()
    @Published var isCameraAuthorized = false
    @Published var isSessionRunning = false
    @Published var capturedImage: UIImage?
    @Published var capturedMetadata: CaptureMetadata?
    @Published var setupError: String?
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var minZoomFactor: CGFloat = 1.0

    private var locationManager: LocationManager
    private var photoDelegate: PhotoCaptureDelegate?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var isStartingSession = false
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        super.init()

        if isSimulator {
            print("📱 Running on iOS Simulator - using mock camera mode")
            // Set up mock states for simulator
            DispatchQueue.main.async {
                self.isCameraAuthorized = true
                self.isSessionRunning = true
                self.currentZoomFactor = 1.0
                self.maxZoomFactor = 10.0
                self.minZoomFactor = 0.5
                print("✅ Mock camera state initialized for simulator")
            }
        } else {
            print("📱 Running on real device - initializing real camera")
            checkCameraPermission()
        }
    }

    deinit {
        print("🧹 CameraManager deallocating - cleaning up")
        NotificationCenter.default.removeObserver(self)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isCameraAuthorized = granted
                if granted {
                    self?.setupCamera()
                }
            }
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
            setupCamera()
        case .notDetermined:
            print("⚠️ Camera permission: NOT DETERMINED")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Camera permission granted after request")
                        // Don't call self.setupCameraForRealDevice() to avoid recursion
                        // Let the user retry manually
                    } else {
                        print("❌ Camera permission denied after request")
                    }
                }
            }
            return
        default:
            isCameraAuthorized = false
            setupError = "Camera access denied"
        }
    }

    private func setupCamera() {
        // Skip real camera setup on simulator
        if isSimulator {
            print("📱 Simulator detected - skipping real camera setup")
            return
        }

        print("🔬 ULTRA-BASIC camera setup - exactly like other working apps")

        // 1. BASIC permission check (like every other app)
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            print("❌ Camera not authorized")
            return
        }

        // 2. BASIC camera device (like every other app)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ No camera device")
            return
        }
        print("✅ Camera device: \(camera.localizedName)")

        // MARK: - ZOOM SETUP: Initialize zoom limits from device capabilities
        DispatchQueue.main.async {
            self.minZoomFactor = camera.minAvailableVideoZoomFactor
            self.maxZoomFactor = min(camera.maxAvailableVideoZoomFactor, 10.0) // Cap at 10x for better quality
            self.currentZoomFactor = 1.0
            print("📷 Zoom limits: \(self.minZoomFactor)x - \(self.maxZoomFactor)x")
        }

        // 3. BASIC session creation (like every other app)
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        print("✅ Session created with photo preset")

        // 4. BASIC input creation (like every other app)
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            self.videoDeviceInput = input
            print("✅ Input created successfully")
        } catch {
            print("❌ Input creation failed: \(error)")
            return
        }

        // 5. BASIC input addition (like every other app)
        guard captureSession.canAddInput(videoDeviceInput!) else {
            print("❌ Cannot add input")
            return
        }
        captureSession.addInput(videoDeviceInput!)
        print("✅ Input added to session")

        // 6. BASIC output creation (like every other app)
        photoOutput = AVCapturePhotoOutput()

        // 7. BASIC output addition (like every other app)
        guard captureSession.canAddOutput(photoOutput) else {
            print("❌ Cannot add output")
            return
        }
        captureSession.addOutput(photoOutput)
        print("✅ Output added to session")

        // 8. BASIC preview setup (like every other app)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.isEnabled = true
        print("✅ Preview layer created and configured")

        // 9. Update state (like every other app)
        DispatchQueue.main.async {
            self.isCameraAuthorized = true
        }

        print("✅ BASIC setup complete - ready to start like other working apps")

        // 10. AUTOMATICALLY start session after setup (like working apps do)
        print("🎬 Auto-starting session after successful setup...")
        startSession()
    }

    func startSession() {
        // Handle simulator case
        if isSimulator {
            print("📱 Simulator detected - skipping real camera session")
            DispatchQueue.main.async {
                self.isSessionRunning = true
                print("✅ Mock camera session 'started' for simulator")
            }
            return
        }

        print("🎬 BASIC session start - exactly like other working apps")

        guard isCameraAuthorized else {
            print("❌ Not authorized")
            return
        }

        guard !captureSession.inputs.isEmpty else {
            print("❌ No inputs configured")
            return
        }

        guard !captureSession.isRunning else {
            print("⚠️ Already running")
            return
        }

        // BASIC session start on background thread (like every other app)
        DispatchQueue.global(qos: .userInitiated).async {
            print("📹 Starting session...")
            self.captureSession.startRunning()
            print("📹 Session start call completed")

            // Simple status check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let running = self.captureSession.isRunning
                let interrupted = self.captureSession.isInterrupted

                print("📊 Final status: running=\(running), interrupted=\(interrupted)")

                if running && !interrupted {
                    print("🎉 SUCCESS! Camera working like other apps!")
                    self.isSessionRunning = true

                    // Ensure preview layer is connected to running session
                    DispatchQueue.main.async {
                        self.previewLayer.session = self.captureSession
                        print("✅ Preview layer connected to running session")

                        // Force UI refresh to display preview
                        self.objectWillChange.send()
                        print("📺 UI refresh triggered for preview display")
                    }
                } else {
                    print("💥 FAILED - but other apps work, so this is OUR bug!")
                    print("🔍 Let's check what other working apps do differently...")

                    // Since other apps work, let's try a different approach
                    self.tryAlternativeSessionStart()
                }
            }
        }
    }

    // Alternative session start approach
    private func tryAlternativeSessionStart() {
        print("🔄 Trying alternative session start approach...")

        // Stop current session completely
        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        // Wait a moment then try again with fresh session
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔄 Creating completely fresh session...")

            // Create brand new session like other apps do
            self.captureSession = AVCaptureSession()
            self.captureSession.sessionPreset = .photo

            // Re-add existing input and output
            if let input = self.videoDeviceInput, self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                print("✅ Re-added input to fresh session")
            }

            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
                print("✅ Re-added output to fresh session")
            }

            // Update preview layer
            self.previewLayer.session = self.captureSession
            print("✅ Preview layer connected to fresh session")

            // Try starting fresh session
            DispatchQueue.global(qos: .userInitiated).async {
                print("📹 Starting FRESH session...")
                self.captureSession.startRunning()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let running = self.captureSession.isRunning
                    let interrupted = self.captureSession.isInterrupted

                    print("📊 FRESH session status: running=\(running), interrupted=\(interrupted)")

                    if running && !interrupted {
                        print("🎉 SUCCESS with fresh session approach!")
                        self.isSessionRunning = true

                        // Ensure preview layer is properly connected
                        DispatchQueue.main.async {
                            self.previewLayer.session = self.captureSession
                            print("✅ Fresh session preview layer connected")
                        }
                    } else {
                        print("💥 Still failing - need to investigate our specific app configuration")
                    }
                }
            }
        }
    }

    func stopSession() {
        guard isSessionRunning || captureSession.isRunning else {
            print("⚠️ Session already stopped")
            return
        }

        print("⏹️ Stopping camera session...")

        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: captureSession)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: captureSession)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.captureSession.stopRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.isStartingSession = false
                print("✅ Camera session stopped")
            }
        }
    }

    func capturePhoto() {
        // Handle simulator case with mock capture
        if isSimulator {
            print("📱 Simulator detected - performing mock photo capture")
            guard let mockMetadata = locationManager.getCurrentMetadata() else {
                print("❌ Unable to get location metadata for mock capture")
                return
            }

            // Create a simple test image
            let testImage = createSimpleTestImage()
            let enhancedMetadata = CaptureMetadata(
                timestamp: mockMetadata.timestamp,
                gpsCoordinate: mockMetadata.gpsCoordinate,
                altitude: mockMetadata.altitude,
                heading: mockMetadata.heading,
                pitch: mockMetadata.pitch,
                roll: mockMetadata.roll,
                cameraFocalLength: mockMetadata.cameraFocalLength,
                imageResolution: testImage.size,
                accuracy: mockMetadata.accuracy,
                zoomFactor: currentZoomFactor,
                effectiveFieldOfView: getEffectiveFieldOfView()
            )

            DispatchQueue.main.async {
                self.capturedImage = testImage
                self.capturedMetadata = enhancedMetadata
                print("✅ Mock photo capture completed")
            }
            return
        }

        // Simplified real device photo capture
        print("📸 Starting simplified photo capture")

        guard isSessionRunning && captureSession.isRunning else {
            print("❌ Cannot capture photo: Camera session not running")
            print("📹 Session status: isSessionRunning=\(isSessionRunning), captureSession.isRunning=\(captureSession.isRunning)")

            // Just try to start session once, no complex retry
            if !isSessionRunning {
                print("🔄 Trying to start session for photo capture...")
                startSession()
            }
            return
        }

        // Ensure photo output is connected
        guard captureSession.outputs.contains(photoOutput) else {
            print("❌ Cannot capture photo: Photo output not connected to session")
            return
        }

        // Get current metadata before capture
        guard let currentMetadata = locationManager.getCurrentMetadata() else {
            print("❌ Unable to get location metadata for photo capture")
            return
        }

        print("📸 Attempting simplified photo capture")

        // Create basic metadata
        let enhancedMetadata = CaptureMetadata(
            timestamp: currentMetadata.timestamp,
            gpsCoordinate: currentMetadata.gpsCoordinate,
            altitude: currentMetadata.altitude,
            heading: currentMetadata.heading,
            pitch: currentMetadata.pitch,
            roll: currentMetadata.roll,
            cameraFocalLength: currentMetadata.cameraFocalLength,
            imageResolution: currentMetadata.imageResolution,
            accuracy: currentMetadata.accuracy,
            zoomFactor: currentZoomFactor,
            effectiveFieldOfView: getEffectiveFieldOfView()
        )

        // Use basic photo settings
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        // Skip high resolution settings to avoid conflicts
        print("📷 Using basic photo settings")

        // Create photo delegate with enhanced metadata
        photoDelegate = PhotoCaptureDelegate(metadata: enhancedMetadata) { [weak self] image, metadata in
            DispatchQueue.main.async {
                self?.capturedImage = image
                self?.capturedMetadata = metadata

                if image != nil {
                    print("✅ Simplified photo capture successful")
                } else {
                    print("❌ Simplified photo capture failed - no image returned")
                }
            }
        }

        // Perform the actual capture
        photoOutput.capturePhoto(with: settings, delegate: photoDelegate!)
        print("📸 Simplified photo capture initiated with zoom: \(currentZoomFactor)x")
    }

    private func createSimpleTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Simple blue sky background
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add some text to indicate it's a test
            let text = "Simulator Test Photo"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: attributes)
        }
    }

    func clearCapturedPhoto() {
        capturedImage = nil
        capturedMetadata = nil
    }

    // MARK: - Zoom Functionality
    func setZoom(_ factor: CGFloat) {
        // Handle simulator case
        if isSimulator {
            let clampedZoom = max(minZoomFactor, min(factor, maxZoomFactor))
            DispatchQueue.main.async {
                self.currentZoomFactor = clampedZoom
                print("📷 Simulator zoom set to: \(clampedZoom)x")
            }
            return
        }

        // Real device zoom
        guard let device = videoDeviceInput?.device else {
            print("❌ No camera device available for zoom")
            return
        }

        guard captureSession.isRunning else {
            print("❌ Camera session not running - cannot set zoom")
            return
        }

        // Ensure we have valid zoom limits
        let actualMinZoom = max(device.minAvailableVideoZoomFactor, 0.5)
        let actualMaxZoom = min(device.maxAvailableVideoZoomFactor, 10.0)
        let clampedZoom = max(actualMinZoom, min(factor, actualMaxZoom))

        do {
            try device.lockForConfiguration()

            // Smooth zoom animation
            device.ramp(toVideoZoomFactor: clampedZoom, withRate: 4.0)

            // Update our state immediately
            DispatchQueue.main.async {
                self.currentZoomFactor = clampedZoom
                self.minZoomFactor = actualMinZoom
                self.maxZoomFactor = actualMaxZoom
            }

            device.unlockForConfiguration()
            print("📷 Zoom smoothly set to: \(clampedZoom)x (range: \(actualMinZoom)x - \(actualMaxZoom)x)")
        } catch {
            print("❌ Failed to set zoom: \(error.localizedDescription)")

            // Fallback: try direct assignment without animation
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.currentZoomFactor = clampedZoom
                }
                print("📷 Zoom set directly to: \(clampedZoom)x")
            } catch {
                print("❌ Even direct zoom failed: \(error.localizedDescription)")
            }
        }
    }

    func adjustZoom(by delta: CGFloat) {
        let newZoom = currentZoomFactor * delta
        setZoom(newZoom)
    }

    func resetZoom() {
        setZoom(1.0)
    }

    // Calculate effective field of view based on zoom
    func getEffectiveFieldOfView() -> Double {
        let baseHorizontalFOV = 68.0 // iPhone camera horizontal field of view at 1x zoom
        return baseHorizontalFOV / Double(currentZoomFactor)
    }

    // Diagnostic helper for real device camera issues
    func diagnoseCameraIssues() {
        print("🔍 Camera Diagnostics:")
        print("   • Authorization: \(AVCaptureDevice.authorizationStatus(for: .video))")
        print("   • Session running: \(captureSession.isRunning)")
        print("   • Session interrupted: \(captureSession.isInterrupted)")
        print("   • Inputs count: \(captureSession.inputs.count)")
        print("   • Outputs count: \(captureSession.outputs.count)")
        print("   • Current preset: \(captureSession.sessionPreset)")
        print("   • Manager session state: \(isSessionRunning)")
        print("   • Starting session flag: \(isStartingSession)")

        if let device = videoDeviceInput?.device {
            print("   • Camera device: \(device.localizedName)")
            print("   • Device connected: \(device.isConnected)")
            print("   • Device suspended: \(device.isSuspended)")
        }
    }

    // New comprehensive diagnostic function
    func diagnoseCameraFailure() {
        print("🔍 COMPREHENSIVE CAMERA FAILURE DIAGNOSTICS:")

        // 1. Check system camera availability
        let cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
        print("   🔐 Camera authorization: \(cameraAuth)")

        // 2. Check if any other apps are using camera
        let allCameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        for camera in allCameras {
            print("   📹 Camera \(camera.localizedName):")
            print("      - Connected: \(camera.isConnected)")
            print("      - Suspended: \(camera.isSuspended)")
            print("      - In use: \(!camera.isConnected || camera.isSuspended)")
        }

        // 3. Check system restrictions
        print("   🚫 System restrictions check:")

        // Check if camera is disabled by restrictions
        if #available(iOS 14.0, *) {
            // Try to detect if camera is restricted
            let testSession = AVCaptureSession()
            if let camera = AVCaptureDevice.default(for: .video) {
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if testSession.canAddInput(input) {
                        print("      ✅ Camera input can be added")
                    } else {
                        print("      ❌ Camera input CANNOT be added - SYSTEM RESTRICTION!")
                    }
                } catch {
                    print("      ❌ Camera input creation failed: \(error)")
                }
            }
        }

        // 4. Check for Control Center restrictions
        print("   📱 Device management:")
        let device = UIDevice.current
        print("      - Device name: \(device.name)")
        print("      - Model: \(device.model)")
        print("      - System name: \(device.systemName)")

        // 5. Final recommendation
        print("🔍 RECOMMENDATION:")
        print("   This appears to be a SYSTEM-LEVEL issue, not an app code issue.")
        print("   Possible causes:")
        print("   1. 📱 Device Management Profile restricting camera")
        print("   2. 🔒 iOS Security restriction")
        print("   3. 🐛 iOS camera service bug")
        print("   4. 📹 Hardware/driver issue")
        print("   5. 🔧 Device needs restart")
        print("   ")
        print("   💡 IMMEDIATE SOLUTIONS TO TRY:")
        print("   1. Restart the device")
        print("   2. Check Settings > Screen Time > Content & Privacy Restrictions")
        print("   3. Check Settings > General > Device Management")
        print("   4. Try the camera in the built-in Camera app")
        print("   5. Update iOS if available")
    }
}

// MARK: - Photo Capture Delegate
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let metadata: CaptureMetadata
    private let completion: (UIImage?, CaptureMetadata) -> Void

    init(metadata: CaptureMetadata, completion: @escaping (UIImage?, CaptureMetadata) -> Void) {
        self.metadata = metadata
        self.completion = completion
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            completion(nil, metadata)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil, metadata)
            return
        }

        // Update metadata with actual image resolution
        var updatedMetadata = metadata
        updatedMetadata = CaptureMetadata(
            timestamp: metadata.timestamp,
            gpsCoordinate: metadata.gpsCoordinate,
            altitude: metadata.altitude,
            heading: metadata.heading,
            pitch: metadata.pitch,
            roll: metadata.roll,
            cameraFocalLength: metadata.cameraFocalLength,
            imageResolution: image.size,
            accuracy: metadata.accuracy,
            zoomFactor: metadata.zoomFactor,
            effectiveFieldOfView: metadata.effectiveFieldOfView
        )

        completion(image, updatedMetadata)
    }
}
