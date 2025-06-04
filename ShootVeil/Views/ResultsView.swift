//
//  ResultsView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI
import CoreLocation
import Photos
import MapKit

struct ResultsView: View {
    let capturedImage: UIImage
    let metadata: CaptureMetadata
    let captureMode: CaptureMode
    let onDismiss: () -> Void
    @ObservedObject var historyManager: CaptureHistoryManager

    @State private var buildingResults: [Building] = []
    @State private var aircraftResults: [Aircraft] = []
    @State private var isLoading = false
    @State private var isLoadingAircraft = false
    @State private var currentLocationAddress = "Loading..."
    @State private var targetLocationAddress = "Loading..."
    @State private var estimatedTargetDistance: Double?
    @State private var isLoadingAddress = true
    @State private var tapPoint: CGPoint = .zero
    @State private var imageSize: CGSize = .zero
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingCustomShareSheet = false
    @State private var showingActivityView = false
    @State private var shareContent: [Any]?
    @State private var showingAircraftSelection = false
    @State private var nearbyAircraftOptions: [Aircraft] = []
    @State private var showingShareOptions = false
    @State private var capturedScreenshot: UIImage? = nil

    @EnvironmentObject var adManager: AdManager

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Image section - 60% of screen height
                        imageSection(geometry: geometry)

                        // Metadata and results section - 40% of screen height
                        metadataAndResultsSection(geometry: geometry)
                    }
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Capture screenshot before opening share sheet with small delay for full render
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            capturedScreenshot = captureCurrentViewAsImage()
                            showingShareOptions = true
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                    }
                }
            }
            .environmentObject(ShareManager.shared)
            .sheet(isPresented: $showingCustomShareSheet) {
                CustomShareSheet(
                    originalImage: capturedImage,
                    metadata: metadata,
                    buildingResults: buildingResults,
                    aircraftResults: aircraftResults,
                    currentAddress: currentLocationAddress,
                    targetAddress: targetLocationAddress,
                    distance: estimatedTargetDistance,
                    preCapuredScreenshot: capturedScreenshot,
                    onShareWithApps: { items in
                        shareContent = items
                        showingActivityView = true
                    }
                )
            }
            .sheet(isPresented: $showingActivityView) {
                if let shareContent = shareContent {
                    ActivityView(items: shareContent)
                }
            }
            .confirmationDialog("Aircraft Selection", isPresented: $showingAircraftSelection) {
                ForEach(nearbyAircraftOptions.indices, id: \.self) { index in
                    Button(nearbyAircraftOptions[index].flightNumber ?? "Unknown Flight") {
                        selectAircraft(nearbyAircraftOptions[index])
                    }
                }
                Button("Cancel", role: .cancel) {
                    nearbyAircraftOptions.removeAll()
                }
            } message: {
                Text("Multiple aircraft detected. Which one did you photograph?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingShareOptions) {
                CustomShareSheet(
                    originalImage: capturedImage,
                    metadata: metadata,
                    buildingResults: buildingResults,
                    aircraftResults: aircraftResults,
                    currentAddress: currentLocationAddress,
                    targetAddress: targetLocationAddress,
                    distance: estimatedTargetDistance,
                    preCapuredScreenshot: capturedScreenshot,
                    onShareWithApps: { items in
                        shareContent = items
                        showingActivityView = true
                    }
                )
            }
            .sheet(isPresented: $showingActivityView) {
                if let shareContent = shareContent {
                    ActivityView(items: shareContent)
                }
            }
        }
        .onAppear {
            loadLocationAddresses()
            saveToHistory()
            checkAndShowAd()
        }
    }

    // MARK: - View Components
    private func imageSection(geometry: GeometryProxy) -> some View {
        ZStack {
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .background(
                    GeometryReader { imageGeometry in
                        Color.clear.onAppear {
                            imageSize = imageGeometry.size
                            // Automatically identify building at center
                            let centerPoint = CGPoint(x: imageGeometry.size.width / 2, y: imageGeometry.size.height / 2)
                            tapPoint = centerPoint
                            identifyBuildingAtTapPoint(centerPoint)
                        }
                    }
                )

            // Center crosshair indicator (same as camera view)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            .frame(width: 60, height: 60)

                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                            .frame(width: 30, height: 30)

                        // Center dot
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)

                        // Cross lines
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 20, height: 1)

                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 1, height: 20)
                    }
                    Spacer()
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .frame(height: geometry.size.height * 0.6)
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleImageTap(at: location)
        }
    }

    private func metadataAndResultsSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    // Metadata info using simplified parameters
                    MetadataInfoView(
                        metadata: metadata,
                        currentLocationAddress: currentLocationAddress,
                        targetLocationAddress: targetLocationAddress,
                        estimatedTargetDistance: estimatedTargetDistance ?? 1000.0,
                        isLoadingAddress: isLoadingAddress
                    )

                    // Results section based on capture mode
                    resultsSection()

                    // Add bottom padding for safe area
                    Spacer(minLength: 20)
                }
                .padding(.top, 10)
            }
        }
        .frame(height: geometry.size.height * 0.4)
        .background(Color(.systemBackground))
    }

    private func resultsSection() -> some View {
        Group {
            switch captureMode {
            case .aircraft:
                // Aircraft mode - show aircraft results
                VStack(spacing: 12) {
                    AircraftIdentificationSection(
                        aircraftResults: aircraftResults,
                        isLoading: isLoadingAircraft,
                        onIdentifyAircraft: {
                            print("🔴 DEBUG: Aircraft button pressed!")
                            Task {
                                print("🔴 DEBUG: Starting async task for aircraft identification")
                                await identifyNearbyAircraft()
                            }
                        }
                    )
                }

            case .landmark:
                // Building identification (only for landmark mode)
                VStack(spacing: 12) {
                    // Loading indicator
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Identifying landmarks...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }

                    // Building Results
                    if !buildingResults.isEmpty {
                        LazyVStack(spacing: 10) {
                            Section("Buildings & Landmarks") {
                                ForEach(buildingResults.indices, id: \.self) { index in
                                    BuildingResultCard(building: buildingResults[index])
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else if !isLoading {
                        VStack {
                            Text("Tap on a building to identify it")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Or wait for automatic identification")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                }

            case .boat:
                // Boat mode - coming soon
                VStack(spacing: 16) {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan)

                    Text("Boat Identification")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Coming Soon!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("This feature will identify ships, boats, and marine vessels in your photos.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private func checkAndShowAd() {
        // Check if user is on ad-supported tier and should see an ad
        let currentTier = SubscriptionManager.shared.currentTier
        let identificationCount = SubscriptionManager.shared.usageThisMonth

        if currentTier == .adSupported && adManager.shouldShowAdAfterIdentification(count: identificationCount) {
            // Small delay to let the view load first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                adManager.showInterstitialAd()
            }
        }
    }

    private func selectAircraft(_ aircraft: Aircraft) {
        aircraftResults = [aircraft]
        showingAircraftSelection = false
        print("✅ Selected aircraft: \(aircraft.flightNumber ?? "Unknown")")
    }

    // MARK: - Identification Functions
    private func identifyBuildingAtTapPoint(_ tapPoint: CGPoint) {
        guard !isLoading else { return }

        isLoading = true
        self.tapPoint = tapPoint

        Task {
            do {
                let buildings = try await IdentificationManager.shared.identifyBuilding(
                    tapPoint: tapPoint,
                    imageSize: imageSize,
                    metadata: metadata,
                    capturedImage: capturedImage
                )

                await MainActor.run {
                    self.buildingResults = buildings
                    self.isLoading = false
                    print("✅ Building identification completed: \(buildings.count) buildings found")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to identify buildings: \(error.localizedDescription)"
                    self.showingError = true
                    print("❌ Building identification failed: \(error)")
                }
            }
        }
    }

    private func identifyNearbyAircraft() async {
        guard !isLoadingAircraft else { return }

        await MainActor.run {
            isLoadingAircraft = true
        }

        do {
            let aircraft = try await IdentificationManager.shared.identifyAircraft(metadata: metadata)

            await MainActor.run {
                if aircraft.count > 1 {
                    // Multiple aircraft found - show selection dialog
                    self.nearbyAircraftOptions = aircraft
                    self.showingAircraftSelection = true
                } else if aircraft.count == 1 {
                    // Single aircraft found - use it directly
                    self.aircraftResults = aircraft
                } else {
                    // No aircraft found
                    self.aircraftResults = []
                }

                self.isLoadingAircraft = false
                print("✅ Aircraft identification completed: \(aircraft.count) aircraft found")
            }
        } catch {
            await MainActor.run {
                self.isLoadingAircraft = false
                self.errorMessage = "Failed to identify aircraft: \(error.localizedDescription)"
                self.showingError = true
                print("❌ Aircraft identification failed: \(error)")
            }
        }
    }

    private func handleImageTap(at location: CGPoint) {
        print("🎯 Image tapped at: \(location)")
        identifyBuildingAtTapPoint(location)
    }

    private func loadLocationAddresses() {
        Task {
            // Load current location address
            do {
                let currentAddress = try await GoogleAPIManager.shared.reverseGeocode(coordinate: metadata.gpsCoordinate)
                await MainActor.run {
                    self.currentLocationAddress = currentAddress
                }
            } catch {
                await MainActor.run {
                    self.currentLocationAddress = "Address unavailable"
                }
                print("❌ Failed to load current address: \(error)")
            }

            // Calculate and load target location address
            let distance = estimatedTargetDistance ?? 1000.0
            let targetCoordinate = calculateTargetCoordinates(
                from: metadata.gpsCoordinate,
                heading: metadata.heading,
                distance: distance
            )

            do {
                let targetAddress = try await GoogleAPIManager.shared.reverseGeocode(coordinate: targetCoordinate)
                await MainActor.run {
                    self.targetLocationAddress = targetAddress
                    self.isLoadingAddress = false
                }
            } catch {
                await MainActor.run {
                    self.targetLocationAddress = "Target address unavailable"
                    self.isLoadingAddress = false
                }
                print("❌ Failed to load target address: \(error)")
            }
        }
    }

    private func saveToHistory() {
        let distanceValue = estimatedTargetDistance ?? 0.0

        print("💾 Saving capture to history...")
        historyManager.addCapture(
            image: capturedImage,
            metadata: metadata,
            buildingResults: buildingResults,
            aircraftResults: aircraftResults,
            currentLocationAddress: currentLocationAddress,
            targetLocationAddress: targetLocationAddress,
            estimatedTargetDistance: distanceValue
        )
        print("✅ Capture saved to history successfully")
    }

    // MARK: - Helper Functions
    private func calculateTargetCoordinates(from location: CLLocationCoordinate2D, heading: Double, distance: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // Earth's radius in meters
        let bearingRadians = heading * .pi / 180.0
        let distanceRadians = distance / earthRadius

        let lat1 = location.latitude * .pi / 180.0
        let lon1 = location.longitude * .pi / 180.0

        let lat2 = asin(sin(lat1) * cos(distanceRadians) + cos(lat1) * sin(distanceRadians) * cos(bearingRadians))
        let lon2 = lon1 + atan2(sin(bearingRadians) * sin(distanceRadians) * cos(lat1), cos(distanceRadians) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }

    private func captureCurrentViewAsImage() -> UIImage? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene?.windows.first

        guard let window = window else {
            print("❌ Unable to capture screenshot: No window found")
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }

        print("📸 Screenshot captured successfully")
        return image
    }
}

// MARK: - Aircraft Identification Section
struct AircraftIdentificationSection: View {
    let aircraftResults: [Aircraft]
    let isLoading: Bool
    let onIdentifyAircraft: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header with identify button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "airplane.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text("Aircraft Identification")
                            .font(.headline)
                            .fontWeight(.semibold)

                        // Auto-detection indicator
                        if !aircraftResults.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Auto-detected")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.1), in: Capsule())
                        }
                    }

                    if aircraftResults.isEmpty {
                        Text("Tap to search for aircraft in your area")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Aircraft detected in camera direction:")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: onIdentifyAircraft) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(aircraftResults.isEmpty ? "Find Aircraft" : "Search More")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(aircraftResults.isEmpty ? Color.blue : Color.orange, in: Capsule())
                }
                .disabled(isLoading)
                .onTapGesture {
                    print("🔴 DEBUG: Button tap gesture detected!")
                }
            }

            // Aircraft results or no results message
            if !aircraftResults.isEmpty {
                ForEach(aircraftResults.indices, id: \.self) { index in
                    AircraftResultCard(aircraft: aircraftResults[index])
                }
            } else if !isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.6))

                    Text("No Aircraft Found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    Text("Try searching again or check a different area")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Metadata Info View
struct MetadataInfoView: View {
    let metadata: CaptureMetadata
    let currentLocationAddress: String?
    let targetLocationAddress: String?
    let estimatedTargetDistance: Double
    let isLoadingAddress: Bool

    // Calculate target coordinates based on user location, heading, and distance
    private var targetCoordinates: CLLocationCoordinate2D {
        return calculateTargetCoordinates(
            from: metadata.gpsCoordinate,
            heading: metadata.heading,
            distance: estimatedTargetDistance
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            // Location Information Section
            VStack(spacing: 12) {
                // Section Header
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text("Location Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                // Current Location Card
                LocationCard(
                    title: "Your Location",
                    address: currentLocationAddress,
                    icon: "figure.stand",
                    iconColor: .green,
                    isLoading: isLoadingAddress,
                    coordinates: metadata.gpsCoordinate
                )

                // Target Location Card with calculated coordinates
                LocationCard(
                    title: "Camera Target",
                    address: targetLocationAddress,
                    icon: "camera.viewfinder",
                    iconColor: .blue,
                    isLoading: isLoadingAddress,
                    distance: estimatedTargetDistance,
                    coordinates: targetCoordinates
                )
            }

            // Technical Metadata Section
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                    Text("Capture Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                // Metadata Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    MetadataItem(
                        title: "Heading",
                        value: String(format: "%.0f°", metadata.heading),
                        icon: "compass",
                        color: .orange
                    )

                    MetadataItem(
                        title: "Altitude",
                        value: String(format: "%.0fm", metadata.altitude),
                        icon: "mountain.2",
                        color: .brown
                    )

                    MetadataItem(
                        title: "Zoom",
                        value: String(format: "%.1fx", metadata.zoomFactor),
                        icon: "magnifyingglass",
                        color: .purple
                    )

                    MetadataItem(
                        title: "Field of View",
                        value: String(format: "%.0f°", metadata.effectiveFieldOfView),
                        icon: "camera.aperture",
                        color: .indigo
                    )

                    MetadataItem(
                        title: "Accuracy",
                        value: String(format: "%.0fm", metadata.accuracy),
                        icon: "target",
                        color: .red
                    )

                    MetadataItem(
                        title: "Timestamp",
                        value: DateFormatter.shortTime.string(from: metadata.timestamp),
                        icon: "clock",
                        color: .teal
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Target Coordinate Calculation
    private func calculateTargetCoordinates(from userLocation: CLLocationCoordinate2D, heading: Double, distance: Double) -> CLLocationCoordinate2D {
        // Convert heading from degrees to radians
        let headingRadians = heading * .pi / 180.0

        // Earth's radius in meters
        let earthRadius = 6371000.0

        // Calculate angular distance
        let angularDistance = distance / earthRadius

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
}

// MARK: - Location Card Component
struct LocationCard: View {
    let title: String
    let address: String?
    let icon: String
    let iconColor: Color
    let isLoading: Bool
    let distance: Double?
    let coordinates: CLLocationCoordinate2D?

    @State private var showingLocationActions = false
    @State private var showingCopiedAlert = false

    init(title: String, address: String?, icon: String, iconColor: Color, isLoading: Bool, distance: Double? = nil, coordinates: CLLocationCoordinate2D? = nil) {
        self.title = title
        self.address = address
        self.icon = icon
        self.iconColor = iconColor
        self.isLoading = isLoading
        self.distance = distance
        self.coordinates = coordinates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if let distance = distance, distance > 0 {
                    Text("\(Int(distance))m away")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                // Add map and copy actions for target location
                if coordinates != nil && title.contains("Target") {
                    Button(action: {
                        showingLocationActions = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
            }

            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding address...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            } else if let address = address {
                Text(address)
                    .font(.body)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Address unavailable")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .confirmationDialog("Location Actions", isPresented: $showingLocationActions) {
            if let coords = coordinates {
                Button("Open in Apple Maps") {
                    openInAppleMaps(coordinate: coords)
                }

                Button("Open in Google Maps") {
                    openInGoogleMaps(coordinate: coords)
                }

                Button("Copy Coordinates") {
                    copyCoordinates(coordinate: coords)
                }

                Button("Copy Address") {
                    copyAddress()
                }
            }

            Button("Cancel", role: .cancel) { }
        }
        .alert("Copied!", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Location information copied to clipboard")
        }
    }

    // MARK: - Location Actions
    private func openInAppleMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = address ?? "Target Location"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps(coordinate: CLLocationCoordinate2D) {
        let urlString = "https://maps.google.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func copyCoordinates(coordinate: CLLocationCoordinate2D) {
        let coordinateString = "\(coordinate.latitude), \(coordinate.longitude)"
        UIPasteboard.general.string = coordinateString
        showingCopiedAlert = true

        // Also provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        print("📋 Copied coordinates: \(coordinateString)")
    }

    private func copyAddress() {
        if let address = address {
            UIPasteboard.general.string = address
            showingCopiedAlert = true

            // Also provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            print("📋 Copied address: \(address)")
        }
    }
}

// MARK: - Metadata Item Component
struct MetadataItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(height: 24)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Aircraft Result Card
struct AircraftResultCard: View {
    let aircraft: Aircraft

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(.blue)
                    Text(aircraft.flightNumber ?? "Unknown Flight")
                        .font(.headline)
                }

                Text(aircraft.aircraftType)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let origin = aircraft.origin, let destination = aircraft.destination {
                    Text("\(origin) → \(destination)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let distance = aircraft.distance {
                    Text(String(format: "%.1f km", distance / 1000))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text(String(format: "%.0f ft", aircraft.altitude))
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(String(format: "%.0f kts", aircraft.speed))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Building Result Card
struct BuildingResultCard: View {
    let building: Building

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: building.isLandmark ? "star.fill" : "building.2.fill")
                        .foregroundColor(building.isLandmark ? .orange : .blue)
                    Text(building.name)
                        .font(.headline)
                        .lineLimit(2)
                }

                Text(building.type.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let address = building.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                if !building.description.isEmpty {
                    Text(building.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let distance = building.distance {
                    Text(String(format: "%.0f m", distance))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text(String(format: "%.0f m", building.height))
                    .font(.caption)
                    .foregroundColor(.gray)

                if let year = building.constructionYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Enhanced Custom Share Sheet with Frame Options
struct CustomShareSheet: View {
    let originalImage: UIImage
    let metadata: CaptureMetadata
    let buildingResults: [Building]
    let aircraftResults: [Aircraft]
    let currentAddress: String?
    let targetAddress: String?
    let distance: Double?
    let preCapuredScreenshot: UIImage?
    let onShareWithApps: ([Any]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var selectedFrameOption: FrameOption = .framed

    enum FrameOption {
        case original
        case framed
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)

                    Text("Share Your Discovery")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Choose your sharing style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Frame Option Selector
                VStack(spacing: 12) {
                    Text("Photo Style")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        // Framed Option
                        Button(action: {
                            selectedFrameOption = .framed
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(height: 60)

                                    VStack(spacing: 4) {
                                        Image(systemName: "photo.artframe")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(height: 8)
                                            .cornerRadius(2)
                                    }
                                }

                                Text("Smart Frame")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("With metadata info")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedFrameOption == .framed ? Color.blue : Color.gray.opacity(0.3),
                                        lineWidth: selectedFrameOption == .framed ? 2 : 1
                                    )
                                    .background(
                                        selectedFrameOption == .framed ?
                                            Color.blue.opacity(0.05) : Color.clear
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Original Option
                        Button(action: {
                            selectedFrameOption = .original
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 60)

                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }

                                Text("Original")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("Clean photo only")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedFrameOption == .original ? Color.blue : Color.gray.opacity(0.3),
                                        lineWidth: selectedFrameOption == .original ? 2 : 1
                                    )
                                    .background(
                                        selectedFrameOption == .original ?
                                            Color.blue.opacity(0.05) : Color.clear
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }

                Divider()

                // Share Options
                VStack(spacing: 16) {
                    // Standard iOS Sharing (WhatsApp, Messages, etc.)
                    Button(action: {
                        shareWithApps()
                    }) {
                        HStack {
                            Image(systemName: "app.badge")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share with Apps")
                                    .font(.headline)
                                Text("WhatsApp, Messages, Mail, Instagram...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Save to Photos
                    Button(action: {
                        saveToPhotos()
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save to Photos")
                                    .font(.headline)
                                Text("Save to your photo library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isProcessing)

                    // Copy to Clipboard
                    Button(action: {
                        copyToClipboard()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy Image")
                                    .font(.headline)
                                Text("Copy to clipboard")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isProcessing)
                }
                .padding(.horizontal)

                Spacer()

                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Enhanced Sharing Actions

    private func shareWithApps() {
        Task {
            isProcessing = true
            let image = await getSelectedImageAsync()
            let content = [image, generateShareText()]

            await MainActor.run {
                self.isProcessing = false
                dismiss()
                // Small delay to prevent conflicts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onShareWithApps(content)
                }
            }
        }
    }

    private func saveToPhotos() {
        Task {
            isProcessing = true
            let imageToSave = await getSelectedImageAsync()

            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.isProcessing = false

                    switch status {
                    case .authorized, .limited:
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAsset(from: imageToSave)
                        }) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    self.successMessage = "Photo saved to your library!"
                                    self.showingSuccess = true
                                } else {
                                    self.errorMessage = "Failed to save photo: \(error?.localizedDescription ?? "Unknown error")"
                                    self.showingError = true
                                }
                            }
                        }

                    case .denied, .restricted:
                        self.errorMessage = "Photo library access denied. Please enable in Settings."
                        self.showingError = true

                    case .notDetermined:
                        self.errorMessage = "Photo library access not determined."
                        self.showingError = true

                    @unknown default:
                        self.errorMessage = "Unknown photo library authorization status."
                        self.showingError = true
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        Task {
            isProcessing = true

            let imageToShare = await getSelectedImageAsync()
            let description = generateShareText()

            await MainActor.run {
                let pasteboard = UIPasteboard.general
                pasteboard.items = [
                    [UIPasteboard.typeAutomatic: imageToShare],
                    [UIPasteboard.typeAutomatic: description]
                ]

                self.isProcessing = false
                self.successMessage = "Image and description copied to clipboard!"
                self.showingSuccess = true
            }
        }
    }

    private func createShareContent() -> [Any] {
        return [getSelectedImage(), generateShareText()]
    }

    private func getSelectedImage() -> UIImage {
        switch selectedFrameOption {
        case .original:
            return originalImage
        case .framed:
            // Return original image immediately, will create frame in background
            return originalImage
        }
    }

    private func getSelectedImageAsync() async -> UIImage {
        switch selectedFrameOption {
        case .original:
            return originalImage
        case .framed:
            // Use actual screenshot instead of programmatic frame
            if let screenshot = preCapuredScreenshot {
                print("📸 Using captured screenshot for sharing")
                return screenshot
            } else {
                print("⚠️ Screenshot failed, falling back to original image")
                return originalImage
            }
        }
    }

    private func generateShareText() -> String {
        switch selectedFrameOption {
        case .original:
            var shareText = "📸 ShootVeil Smart Capture\n"

            if let target = targetAddress {
                shareText += "📍 \(target)\n"
            }

            if distance != nil {
                shareText += "📏 \(distance!) away\n"
            }

            if !buildingResults.isEmpty {
                shareText += "🏢 \(buildingResults.count) buildings identified\n"
            }

            if !aircraftResults.isEmpty {
                shareText += "✈️ \(aircraftResults.count) aircraft spotted\n"
            }

            shareText += "\n🚀 Get the app: shootveil.ai\n#ShootVeil #AICamera"

            return shareText

        case .framed:
            var shareText = "📸 ShootVeil AI Smart Capture"
            shareText += "\n\n🚀 Get the app: shootveil.ai"
            shareText += "\n#ShootVeil #AICamera #SmartPhotography"

            return shareText
        }
    }
}

// MARK: - Activity View for iOS Sharing
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.modalPresentationStyle = .pageSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    if let image = UIImage(systemName: "photo") {
        ResultsView(
            capturedImage: image,
            metadata: CaptureMetadata(
                timestamp: Date(),
                gpsCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                altitude: 100,
                heading: 45,
                pitch: 0,
                roll: 0,
                cameraFocalLength: 4.25,
                imageResolution: CGSize(width: 1920, height: 1080),
                accuracy: 5.0,
                zoomFactor: 1.0,
                effectiveFieldOfView: 68.0
            ),
            captureMode: .landmark,
            onDismiss: {},
            historyManager: CaptureHistoryManager()
        )
    }
}
