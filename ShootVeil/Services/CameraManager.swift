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
            requestCameraPermission()
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

        print("📱 Setting up camera for real device with simplified configuration")

        guard isCameraAuthorized else {
            setupError = "Camera not authorized"
            return
        }

        // Check if camera hardware is available
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            setupError = "Camera hardware not available on this device"
            print("⚠️ Camera hardware not available - device may not support camera features")
            return
        }

        // Use main queue for simplified setup to avoid threading issues
        print("🔧 Using simplified main-queue camera setup")

        // Create a completely new session to avoid any stuck state
        captureSession = AVCaptureSession()
        photoOutput = AVCapturePhotoOutput()

        captureSession.beginConfiguration()

        // Use medium quality preset instead of photo to reduce conflicts
        if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
            print("📷 Session preset set to medium (simplified)")
        } else if captureSession.canSetSessionPreset(.low) {
            captureSession.sessionPreset = .low
            print("📷 Session preset set to low (fallback)")
        } else {
            print("⚠️ Cannot set any session preset")
        }

        // Add camera input with minimal configuration
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            setupError = "Back camera not available"
            captureSession.commitConfiguration()
            return
        }

        print("📷 Camera device: \(camera.localizedName)")

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
                videoDeviceInput = cameraInput
                print("✅ Camera input added successfully")

                // Initialize zoom values on main queue
                DispatchQueue.main.async {
                    self.minZoomFactor = camera.minAvailableVideoZoomFactor
                    self.maxZoomFactor = camera.maxAvailableVideoZoomFactor
                    self.currentZoomFactor = camera.videoZoomFactor
                    print("📷 Zoom range: \(camera.minAvailableVideoZoomFactor)x - \(camera.maxAvailableVideoZoomFactor)x")
                }
            } else {
                setupError = "Cannot add camera input"
                captureSession.commitConfiguration()
                return
            }
        } catch {
            setupError = "Failed to create camera input: \(error.localizedDescription)"
            captureSession.commitConfiguration()
            return
        }

        // Add photo output with minimal configuration
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            print("✅ Photo output added successfully")

            // Skip high-resolution settings that might cause conflicts
            print("📷 Using standard resolution to avoid conflicts")
        } else {
            setupError = "Cannot add photo output"
            captureSession.commitConfiguration()
            return
        }

        captureSession.commitConfiguration()
        print("📷 Simplified session configuration committed with \(captureSession.inputs.count) inputs and \(captureSession.outputs.count) outputs")

        // Setup preview layer on main thread
        DispatchQueue.main.async {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer.videoGravity = .resizeAspectFill
            print("✅ Simplified camera setup completed successfully")
        }
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

        print("📱 Starting camera session with background thread (avoiding ads conflicts)")

        guard isCameraAuthorized else {
            print("❌ Cannot start session: Camera not authorized")
            return
        }

        guard !captureSession.inputs.isEmpty else {
            print("❌ Cannot start session: No camera input configured")
            setupCamera() // Try to setup again
            return
        }

        // Prevent multiple simultaneous start attempts
        guard !isStartingSession else {
            print("⚠️ Session start already in progress")
            return
        }

        guard !captureSession.isRunning else {
            print("⚠️ Session already running")
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
            return
        }

        isStartingSession = true
        print("🎬 Starting camera session...")
        print("📊 Session config: inputs=\(captureSession.inputs.count), outputs=\(captureSession.outputs.count)")

        // Remove any existing observers
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: captureSession)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: captureSession)

        // Add minimal observers
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            print("⚠️ Camera session interrupted")
            self?.isSessionRunning = false
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            print("✅ Camera session interruption ended")
        }

        // Use background thread to avoid Google Ads conflicts
        print("🔧 Starting session on background thread to avoid ads conflicts")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Add small delay to ensure Google Ads isn't competing
            Thread.sleep(forTimeInterval: 0.2)

            self.captureSession.startRunning()

            // Check status on main thread
            DispatchQueue.main.async {
                let isRunning = self.captureSession.isRunning
                let isInterrupted = self.captureSession.isInterrupted

                print("📊 Session state: running=\(isRunning), interrupted=\(isInterrupted)")

                // Update state
                self.isSessionRunning = isRunning
                self.isStartingSession = false

                if isRunning {
                    print("✅ Camera session started successfully")
                    // Notify AdManager that camera is working
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        AdManager.shared.startAdsAfterCameraSetup()
                    }
                } else {
                    print("❌ Camera session failed to start")
                    if isInterrupted {
                        print("💡 Session is interrupted - likely Google Ads conflict")
                        print("💡 Ads will be delayed to avoid camera conflicts")
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
        guard let device = videoDeviceInput?.device else { return }

        do {
            try device.lockForConfiguration()

            let clampedZoom = max(minZoomFactor, min(factor, maxZoomFactor))
            device.videoZoomFactor = clampedZoom

            DispatchQueue.main.async {
                self.currentZoomFactor = clampedZoom
            }

            device.unlockForConfiguration()
            print("📷 Zoom set to: \(clampedZoom)x")
        } catch {
            print("❌ Failed to set zoom: \(error.localizedDescription)")
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
