//
//  ContentView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI
import CoreLocation
import AVFoundation

// MARK: - Capture Mode Enum
enum CaptureMode: String, CaseIterable {
    case landmark = "landmark"
    case aircraft = "aircraft"
    case boat = "boat"

    var title: String {
        switch self {
        case .landmark: return "Landmarks"
        case .aircraft: return "Aircraft"
        case .boat: return "Boats"
        }
    }

    var subtitle: String {
        switch self {
        case .landmark: return "Buildings & Points of Interest"
        case .aircraft: return "Flights & Aviation"
        case .boat: return "Ships & Vessels"
        }
    }

    var icon: String {
        switch self {
        case .landmark: return "building.2.fill"
        case .aircraft: return "airplane"
        case .boat: return "sailboat.fill"
        }
    }

    var color: Color {
        switch self {
        case .landmark: return .blue
        case .aircraft: return .orange
        case .boat: return .cyan
        }
    }

    var isAvailable: Bool {
        switch self {
        case .landmark, .aircraft: return true
        case .boat: return false  // Back to coming soon
        }
    }
}

struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    @State private var showingHomeScreen = true
    @State private var showingSplash = true
    @State private var selectedCaptureMode: CaptureMode?
    @StateObject private var historyManager = CaptureHistoryManager()

    var body: some View {
        Group {
            if showingSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingSplash = false
                    }
                }
            } else if hasCompletedOnboarding {
                if showingHomeScreen {
                    HomeScreenView(
                        onCameraSelected: { mode in
                            selectedCaptureMode = mode
                            showingHomeScreen = false
                        },
                        historyManager: historyManager
                    )
                } else {
                    MainAppView(
                        historyManager: historyManager,
                        captureMode: selectedCaptureMode ?? .landmark,
                        onHomeRequested: {
                            showingHomeScreen = true
                            selectedCaptureMode = nil
                        }
                    )
                }
            } else {
                WelcomeView {
                    hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            }
        }
        .onAppear {
            // Check if user has completed onboarding before
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
    }
}

// MARK: - Home Screen View
struct HomeScreenView: View {
    let onCameraSelected: (CaptureMode) -> Void
    @ObservedObject var historyManager: CaptureHistoryManager
    @State private var showingHistory = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("ShootVeil")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Intelligent Object Identification")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Capture Mode Selection
                    VStack(spacing: 24) {
                        Text("What would you like to identify?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 16) {
                            ForEach(CaptureMode.allCases, id: \.self) { mode in
                                CaptureModeButton(
                                    mode: mode,
                                    onSelected: { onCameraSelected(mode) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Secondary Menu Options
                    VStack(spacing: 16) {
                        // History Button
                        MenuButton(
                            icon: "clock.fill",
                            title: "View History",
                            subtitle: "\(historyManager.items.count) captures",
                            color: .purple,
                            action: { showingHistory = true }
                        )

                        // Settings Button
                        MenuButton(
                            icon: "gear",
                            title: "Settings",
                            subtitle: "API keys & preferences",
                            color: .gray,
                            action: { showingSettings = true }
                        )
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Quick Stats
                    if !historyManager.items.isEmpty {
                        VStack(spacing: 8) {
                            Text("Recent Activity")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 24) {
                                StatChip(
                                    value: "\(historyManager.items.count)",
                                    label: "Captures",
                                    color: .blue
                                )

                                StatChip(
                                    value: "\(historyManager.items.compactMap { $0.buildingResults.count }.reduce(0, +))",
                                    label: "Buildings",
                                    color: .orange
                                )

                                StatChip(
                                    value: "\(historyManager.items.compactMap { $0.aircraftResults.count }.reduce(0, +))",
                                    label: "Aircraft",
                                    color: .green
                                )
                            }
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
                .environmentObject(historyManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            historyManager.loadHistory()
        }
    }
}

// MARK: - Capture Mode Button Component
struct CaptureModeButton: View {
    let mode: CaptureMode
    let onSelected: () -> Void

    var body: some View {
        Button(action: mode.isAvailable ? onSelected : {}) {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.title)
                    .foregroundColor(mode.isAvailable ? .white : .gray)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mode.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(mode.isAvailable ? .white : .gray)

                        if !mode.isAvailable {
                            Text("COMING SOON")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }

                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundColor(mode.isAvailable ? .white.opacity(0.9) : .gray.opacity(0.7))
                }

                Spacer()

                if mode.isAvailable {
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                mode.isAvailable ?
                    AnyView(LinearGradient(
                        gradient: Gradient(colors: [mode.color, mode.color.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )) :
                    AnyView(Color.gray.opacity(0.3))
            )
            .cornerRadius(16)
            .shadow(color: mode.isAvailable ? mode.color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!mode.isAvailable)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Menu Button Component
struct MenuButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Chip Component
struct StatChip: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Main App View with Tab Navigation
struct MainAppView: View {
    @ObservedObject var historyManager: CaptureHistoryManager
    let captureMode: CaptureMode
    let onHomeRequested: () -> Void
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera Tab
            EnhancedCameraView(historyManager: historyManager, captureMode: captureMode, onHomeRequested: onHomeRequested)
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Camera")
                }
                .tag(0)

            // History Tab
            HistoryView()
                .environmentObject(historyManager)
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(1)
                .badge(historyManager.items.count > 0 ? historyManager.items.count : 0)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Enhanced Camera View
struct EnhancedCameraView: View {
    @ObservedObject var historyManager: CaptureHistoryManager
    let captureMode: CaptureMode
    let onHomeRequested: () -> Void
    @StateObject private var locationManager = LocationManager()
    @StateObject private var cameraManager: CameraManager
    @State private var showingResultsView = false
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var accumulatedZoom: CGFloat = 1.0

    // MARK: - Version 1.1: Tap-to-Identify State Variables
    @State private var showingObjectSelection = false
    @State private var capturedImageForSelection: UIImage?
    @State private var capturedMetadataForSelection: CaptureMetadata?
    @State private var objectTapLocation: CGPoint?
    @State private var isProcessingIdentification = false
    @State private var processingProgress: Double = 0.0
    @State private var processingStatus = ""
    @State private var showingTapIndicator = false

    init(historyManager: CaptureHistoryManager, captureMode: CaptureMode, onHomeRequested: @escaping () -> Void) {
        self.historyManager = historyManager
        self.captureMode = captureMode
        self.onHomeRequested = onHomeRequested
        let locationMgr = LocationManager()
        self._locationManager = StateObject(wrappedValue: locationMgr)
        // Initialize CameraManager with the same LocationManager instance
        self._cameraManager = StateObject(wrappedValue: CameraManager(locationManager: locationMgr))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraManager.isCameraAuthorized && locationManager.isLocationEnabled {
                ZStack {
                    // Camera preview with improved pinch-to-zoom
                    if !isRunningOnSimulator {
                        CameraPreviewView(cameraManager: cameraManager)
                            .ignoresSafeArea()
                            .scaleEffect(1.0) // Keep at 1.0, let camera handle zoom
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        // Calculate delta from last value
                                        let delta = value / lastScaleValue
                                        lastScaleValue = value

                                        // Apply zoom with proper constraints
                                        let newZoom = cameraManager.currentZoomFactor * delta
                                        let clampedZoom = max(cameraManager.minZoomFactor, min(newZoom, cameraManager.maxZoomFactor))

                                        // Only apply if within valid range and significant change
                                        if abs(clampedZoom - cameraManager.currentZoomFactor) > 0.05 {
                                            cameraManager.setZoom(clampedZoom)

                                            // Add haptic feedback for significant changes
                                            if abs(delta - 1.0) > 0.15 {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        lastScaleValue = 1.0

                                        // Haptic feedback when gesture ends
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()

                                        print("🔍 Final zoom: \(cameraManager.currentZoomFactor)x")
                                    }
                            )
                    } else {
                        SimulatorCameraView()
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScaleValue
                                        lastScaleValue = value

                                        let newZoom = cameraManager.currentZoomFactor * delta
                                        let clampedZoom = max(cameraManager.minZoomFactor, min(newZoom, cameraManager.maxZoomFactor))
                                        cameraManager.currentZoomFactor = clampedZoom
                                        print("🔍 Simulator zoom: \(clampedZoom)x")
                                    }
                                    .onEnded { _ in
                                        lastScaleValue = 1.0
                                        print("🔍 Simulator final zoom: \(cameraManager.currentZoomFactor)x")
                                    }
                            )
                    }

                    // Modern UI Overlay
                    ModernCameraOverlay(
                        cameraManager: cameraManager,
                        locationManager: locationManager,
                        captureMode: captureMode,
                        onCapture: {
                            // Normal capture for all modes
                            if isRunningOnSimulator {
                                simulatePhotoCapture()
                            } else {
                                cameraManager.capturePhoto()
                            }
                        },
                        onHome: onHomeRequested
                    )
                }
            } else {
                PermissionView(
                    cameraAuthorized: cameraManager.isCameraAuthorized,
                    locationEnabled: locationManager.isLocationEnabled,
                    onRequestCamera: { cameraManager.requestCameraPermission() },
                    onRequestLocation: { locationManager.requestLocationPermission() }
                )
            }
        }
        .onAppear {
            print("🎬 Camera view appeared - starting services...")
            locationManager.startLocationUpdates()
            if !isRunningOnSimulator {
                // Start camera session with a longer delay to ensure proper initialization
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔧 Attempting to start camera session after setup delay...")
                    cameraManager.startSession()
                }
            }
        }
        .onDisappear {
            print("🛑 Camera view disappeared - stopping services...")
            cameraManager.stopSession()
            locationManager.stopLocationUpdates()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("📱 App became active - ensuring camera session is running")
            if !isRunningOnSimulator && !cameraManager.isSessionRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cameraManager.startSession()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App will resign active - maintaining camera session")
            // Don't stop session when app goes to background, just log it
        }
        .fullScreenCover(isPresented: $showingResultsView) {
            if let image = cameraManager.capturedImage,
               let metadata = cameraManager.capturedMetadata {
                ResultsView(
                    capturedImage: image,
                    metadata: metadata,
                    captureMode: captureMode,
                    onDismiss: {
                        showingResultsView = false
                        cameraManager.capturedImage = nil
                        cameraManager.capturedMetadata = nil
                    },
                    historyManager: historyManager
                )
            }
        }
        // MARK: - Version 1.1: Object Selection Sheet
        .fullScreenCover(isPresented: $showingObjectSelection) {
            if let image = capturedImageForSelection,
               let metadata = capturedMetadataForSelection {
                ObjectSelectionView(
                    capturedImage: image,
                    metadata: metadata,
                    captureMode: captureMode,
                    onDismiss: {
                        showingObjectSelection = false
                        capturedImageForSelection = nil
                        capturedMetadataForSelection = nil
                        objectTapLocation = nil
                    },
                    onIdentificationComplete: { result in
                        // Handle successful identification
                        showingObjectSelection = false

                        // Navigate to results with enhanced data
                        cameraManager.capturedImage = image
                        cameraManager.capturedMetadata = metadata
                        showingResultsView = true
                    },
                    historyManager: historyManager
                )
            }
        }
        .onChange(of: cameraManager.capturedImage) { oldValue, newValue in
            if newValue != nil {
                // Version 1.1: Check if we should go to object selection or direct results
                if let metadata = cameraManager.capturedMetadata {
                    // Store for object selection
                    capturedImageForSelection = newValue
                    capturedMetadataForSelection = metadata
                    showingObjectSelection = true
                } else {
                    // Fallback to original flow
                    showingResultsView = true
                }
            }
        }
    }

    private var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func simulatePhotoCapture() {
        // Create a realistic test image for simulator
        let testImage = createRealisticTestImage()

        if let currentMetadata = locationManager.getCurrentMetadata() {
            let enhancedMetadata = CaptureMetadata(
                timestamp: currentMetadata.timestamp,
                gpsCoordinate: currentMetadata.gpsCoordinate,
                altitude: currentMetadata.altitude,
                heading: currentMetadata.heading,
                pitch: currentMetadata.pitch,
                roll: currentMetadata.roll,
                cameraFocalLength: currentMetadata.cameraFocalLength,
                imageResolution: CGSize(width: 1200, height: 800), // Realistic photo resolution
                accuracy: currentMetadata.accuracy,
                zoomFactor: cameraManager.currentZoomFactor,
                effectiveFieldOfView: 68.0 / cameraManager.currentZoomFactor
            )

            cameraManager.capturedImage = testImage
            cameraManager.capturedMetadata = enhancedMetadata
        }
    }

    private func createRealisticTestImage() -> UIImage {
        // Try to use a bundled test photo first
        if let bundledImage = UIImage(named: "test-photo") {
            return bundledImage
        }

        // Fallback: Create a photorealistic image using actual photo techniques
        return createPhotorealisticImage()
    }

    private func createPhotorealisticImage() -> UIImage {
        let size = CGSize(width: 400, height: 300) // Much smaller size

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext

            // Simple, memory-efficient background
            let skyColor = UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0)
            cgContext.setFillColor(skyColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))

            // Simple clouds
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            cgContext.fillEllipse(in: CGRect(x: 80, y: 40, width: 60, height: 30))
            cgContext.fillEllipse(in: CGRect(x: 200, y: 60, width: 80, height: 40))

            // Simple buildings
            cgContext.setFillColor(UIColor.gray.cgColor)
            cgContext.fill(CGRect(x: 50, y: 180, width: 40, height: 120))
            cgContext.fill(CGRect(x: 120, y: 160, width: 50, height: 140))
            cgContext.fill(CGRect(x: 200, y: 170, width: 45, height: 130))
            cgContext.fill(CGRect(x: 280, y: 150, width: 60, height: 150))

            // Simple ground
            cgContext.setFillColor(UIColor(red: 0.4, green: 0.6, blue: 0.4, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(x: 0, y: 280, width: Int(size.width), height: 20))
        }
    }
}

// MARK: - Modern Camera Overlay
struct ModernCameraOverlay: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var locationManager: LocationManager
    let captureMode: CaptureMode
    let onCapture: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack {
            // Top Status Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Current capture mode
                    HStack {
                        Image(systemName: captureMode.icon)
                            .foregroundColor(captureMode.color)
                        Text("\(captureMode.title) Mode")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text(locationStatusText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Image(systemName: "location.north.fill")
                            .foregroundColor(.blue)
                        Text(compassStatusText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )

                Spacer()

                // Settings/Menu Button
                Button(action: onHome) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding()

            Spacer()

            // Center Crosshair
            CrosshairView()

            Spacer()

            // Bottom Controls
            HStack {
                // Zoom Controls
                VStack(spacing: 12) {
                    Text(String(format: "%.1fx", cameraManager.currentZoomFactor))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())

                    VStack(spacing: 8) {
                        Button(action: {
                            let newZoom = cameraManager.currentZoomFactor * 1.3
                            cameraManager.setZoom(newZoom)

                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Button(action: {
                            cameraManager.resetZoom()

                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }) {
                            Text("1x")
                                .font(.caption)
                                .fontWeight(.bold)
                        }

                        Button(action: {
                            let newZoom = cameraManager.currentZoomFactor / 1.3
                            cameraManager.setZoom(newZoom)

                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }) {
                            Image(systemName: "minus")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }

                Spacer()

                // Capture Button
                Button(action: onCapture) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)

                        Circle()
                            .stroke(.black, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }
                }

                Spacer()

                // Instructions
                VStack(spacing: 8) {
                    InstructionChip(
                        icon: "target",
                        text: "Point at target",
                        color: .blue
                    )

                    InstructionChip(
                        icon: "magnifyingglass",
                        text: "Pinch to zoom",
                        color: .purple
                    )

                    InstructionChip(
                        icon: "camera.shutter.button",
                        text: "Tap to capture",
                        color: .green
                    )
                }
            }
            .padding()
        }
    }

    private var locationStatusText: String {
        if let location = locationManager.location {
            return String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude)
        } else {
            return "No GPS"
        }
    }

    private var compassStatusText: String {
        if let heading = locationManager.heading {
            let direction = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
            return String(format: "%.0f°", direction)
        } else {
            return "No Compass"
        }
    }
}

// MARK: - UI Components
struct CrosshairView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.8), lineWidth: 2)
                .frame(width: 80, height: 80)

            Circle()
                .stroke(.red.opacity(0.6), lineWidth: 1)
                .frame(width: 40, height: 40)

            Circle()
                .fill(.red)
                .frame(width: 4, height: 4)

            Rectangle()
                .fill(.white.opacity(0.8))
                .frame(width: 30, height: 1)

            Rectangle()
                .fill(.white.opacity(0.8))
                .frame(width: 1, height: 30)
        }
    }
}

struct InstructionChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.8), in: Capsule())
    }
}

struct SimulatorCameraView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.7))

                Text("Simulator Camera View")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.top)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black

        print("📺 Creating camera preview view")

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Always update the preview layer connection
        DispatchQueue.main.async {
            let previewLayer = cameraManager.previewLayer

            // Only proceed if the view has proper dimensions
            guard uiView.bounds.width > 0 && uiView.bounds.height > 0 else {
                print("📺 Waiting for proper view layout - bounds: \(uiView.bounds)")

                // Schedule another update when layout is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateUIView(uiView, context: context)
                }
                return
            }

            // Set frame to match view bounds
            previewLayer.frame = uiView.bounds

            // Remove from any existing superlayer first
            previewLayer.removeFromSuperlayer()

            // Add to the current view
            uiView.layer.addSublayer(previewLayer)

            print("📺 Preview layer updated: frame=\(previewLayer.frame), session=\(previewLayer.session != nil ? "connected" : "nil")")

            // Force the layer to update if session is running
            if cameraManager.isSessionRunning && cameraManager.captureSession.isRunning {
                previewLayer.connection?.isEnabled = true
                print("📺 Preview connection enabled for running session")
            }
        }
    }
}

// MARK: - Permission View
struct PermissionView: View {
    let cameraAuthorized: Bool
    let locationEnabled: Bool
    let onRequestCamera: () -> Void
    let onRequestLocation: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("ShootVeil")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Permissions Required")
                .font(.title2)
                .foregroundColor(.gray)

            VStack(spacing: 15) {
                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera Access",
                    description: "Required to capture photos",
                    isGranted: cameraAuthorized,
                    action: onRequestCamera
                )

                PermissionRow(
                    icon: "location.fill",
                    title: "Location Access",
                    description: "Required for spatial identification",
                    isGranted: locationEnabled,
                    action: onRequestLocation
                )
            }
            .padding()
        }
        .padding()
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if !isGranted {
                Button("Grant", action: action)
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Version 1.1: Object Selection View
struct ObjectSelectionView: View {
    let capturedImage: UIImage
    let metadata: CaptureMetadata
    let captureMode: CaptureMode
    let onDismiss: () -> Void
    let onIdentificationComplete: (IdentificationResult) -> Void
    @ObservedObject var historyManager: CaptureHistoryManager

    @State private var objectTapLocation: CGPoint?
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processingStatus = ""
    @State private var showingTapIndicator = false
    @State private var tapIndicatorLocation: CGPoint = .zero
    @StateObject private var identificationManager = IdentificationManager.shared
    @StateObject private var unvealCalculator = UnvealCalculator.shared

    // MARK: - Unveal v1.0 Integration
    @State private var unvealResult: UnvealResult?
    @State private var showingUnvealFeedback = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Image with tap detection
                ZStack {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture { location in
                            handleObjectTap(at: location)
                        }

                    // Tap indicator
                    if showingTapIndicator, let tapLocation = objectTapLocation {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 60, height: 60)
                            .position(tapLocation)
                            .animation(.easeInOut(duration: 0.3), value: showingTapIndicator)
                    }

                    // Processing overlay
                    if isProcessing {
                        VStack(spacing: 16) {
                            ProgressView(value: processingProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 200)

                            Text(processingStatus)
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
                .frame(maxHeight: .infinity)

                // Bottom instruction panel
                VStack(spacing: 16) {
                    if objectTapLocation == nil {
                        Text("👆 Tap on what you want to identify in the photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Text("🎯 Object marked for identification")
                                .font(.headline)
                                .foregroundColor(.green)

                            Button(action: processIdentification) {
                                Text("🧠 Identify with Unveal v1.0")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                            .padding(.horizontal)

                            // Show Unveal feedback button after identification
                            if let unvealResult = unvealResult {
                                Button(action: {
                                    showingUnvealFeedback = true
                                }) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                            .font(.title3)
                                        Text("Help Train Unveal v1.0")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.purple)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Button(action: onDismiss) {
                        Text("Cancel")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .sheet(isPresented: $showingUnvealFeedback) {
            if let unvealResult = unvealResult {
                UnvealFeedbackView(
                    unvealResult: unvealResult,
                    originalImage: capturedImage,
                    onFeedbackSubmitted: {
                        print("🎓 Unveal v1.0 training data submitted!")
                    }
                )
            }
        }
    }

    private func handleObjectTap(at location: CGPoint) {
        objectTapLocation = location
        tapIndicatorLocation = location
        showingTapIndicator = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Hide indicator after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingTapIndicator = false
        }
    }

    private func processIdentification() {
        guard let tapLocation = objectTapLocation else { return }

        isProcessing = true
        processingProgress = 0.0
        processingStatus = "🧠 Unveal v1.0: Calculating target location..."

        // Step 1: Unveal v1.0 Calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processingProgress = 0.2
            processingStatus = "📍 Analyzing GPS and compass data..."

            // Calculate using Unveal v1.0
            let estimatedDistance = calculateEstimatedDistance(tapLocation: tapLocation)

            let unvealResult = unvealCalculator.calculateTargetLocation(
                userLocation: metadata.gpsCoordinate,
                heading: metadata.heading,
                distance: estimatedDistance,
                zoomFactor: metadata.zoomFactor,
                fieldOfView: metadata.effectiveFieldOfView,
                altitude: metadata.altitude,
                deviceOrientation: "portrait", // Could get from metadata
                timestamp: metadata.timestamp
            )

            self.unvealResult = unvealResult

            // Step 2: AI Identification
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                processingProgress = 0.6
                processingStatus = "🔍 AI identification in progress..."

                Task {
                    do {
                        // Use existing identification methods with tap location
                        let (buildings, aircraft) = try await identificationManager.identifyObjects(
                            image: capturedImage,
                            metadata: metadata,
                            tapLocation: tapLocation,
                            captureMode: captureMode
                        )

                        await MainActor.run {
                            processingProgress = 1.0
                            processingStatus = "✅ Identification complete!"

                            // Create and return result
                            let result = IdentificationResult(
                                id: UUID().uuidString,
                                type: captureMode == .landmark ? .landmark : .aircraft,
                                confidence: unvealResult.confidence,
                                name: buildings.first?.name ?? aircraft.first?.flightNumber ?? "Unknown Object",
                                description: "Identified using Unveal v1.0 with \(String(format: "%.1f%%", unvealResult.confidence * 100)) confidence",
                                distance: estimatedDistance,
                                additionalInfo: [
                                    "unveal_version": "1.0",
                                    "calculation_method": unvealResult.calculationMethod,
                                    "target_coordinates": "\(unvealResult.targetCoordinates.latitude), \(unvealResult.targetCoordinates.longitude)"
                                ],
                                timestamp: Date()
                            )

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isProcessing = false
                                onIdentificationComplete(result)
                            }
                        }

                    } catch {
                        await MainActor.run {
                            print("❌ Identification failed: \(error)")
                            processingStatus = "❌ Identification failed"

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isProcessing = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func calculateEstimatedDistance(tapLocation: CGPoint) -> Double {
        // Enhanced distance calculation using tap location and image analysis
        let imageSize = capturedImage.size
        let centerPoint = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)

        // Calculate offset from center
        let offsetX = abs(tapLocation.x - centerPoint.x)
        let offsetY = abs(tapLocation.y - centerPoint.y)
        let totalOffset = sqrt(offsetX * offsetX + offsetY * offsetY)

        // Base distance calculation (simplified)
        let baseDistance = 100.0 + (Double(totalOffset) * 2.0)

        // Adjust for zoom factor
        let zoomAdjustedDistance = baseDistance / metadata.zoomFactor

        // Adjust for altitude (higher altitude = further objects)
        let altitudeAdjustedDistance = zoomAdjustedDistance + (metadata.altitude * 0.5)

        return max(50.0, min(altitudeAdjustedDistance, 5000.0)) // Clamp between 50m and 5km
    }
}

// MARK: - Camera Permission Manager
class CameraPermissionManager: ObservableObject {
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined

    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async {
                self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    func checkPermission() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
}

#Preview {
    ContentView()
}
