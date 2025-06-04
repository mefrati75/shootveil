//
//  HistoryView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI
import CoreLocation
import MapKit
import Photos

struct HistoryView: View {
    @EnvironmentObject var historyManager: CaptureHistoryManager
    @State private var selectedItem: CaptureHistoryItem?
    @State private var showingResultsView = false
    @State private var showingShareOptions = false
    @State private var showingActivityView = false
    @State private var shareContent: [Any]? = nil
    @State private var capturedScreenshot: UIImage? = nil

    var body: some View {
        NavigationView {
            VStack {
                if historyManager.items.isEmpty {
                    Text("No history items")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(historyManager.items) { item in
                            BasicHistoryItemRow(item: item)
                                .onTapGesture {
                                    handleItemTap(item)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Capture History")
            .onAppear {
                print("📖 DEBUG: HistoryView onAppear called")
                historyManager.loadHistory()
            }
        }
        .sheet(isPresented: $showingResultsView) {
            if let item = selectedItem {
                HistoryResultsView(item: item) {
                    handleDismiss()
                }
            } else {
                ErrorView {
                    handleDismiss()
                }
            }
        }
    }

    private func handleItemTap(_ item: CaptureHistoryItem) {
        print("🔍 DEBUG: History item tapped!")
        print("🔍 DEBUG: Item ID: \(item.id)")
        print("🔍 DEBUG: Item timestamp: \(item.timestamp)")
        print("🔍 DEBUG: Has image: \(item.image)")
        print("🔍 DEBUG: Target address: \(item.targetLocationAddress ?? "nil")")
        print("🔍 DEBUG: Building results: \(item.buildingResults.count)")
        print("🔍 DEBUG: Aircraft results: \(item.aircraftResults.count)")

        selectedItem = item
        showingResultsView = true
        print("🚀 DEBUG: Set selectedItem and showingResultsView to true")
    }

    private func handleDismiss() {
        print("📱 DEBUG: HistoryResultsView onDismiss called!")
        showingResultsView = false
        selectedItem = nil
        print("📱 DEBUG: Reset showingResultsView and selectedItem")
    }
}

struct BasicHistoryItemRow: View {
    let item: CaptureHistoryItem

    var body: some View {
        HStack {
            Image(uiImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()

            VStack(alignment: .leading) {
                Text("Capture")
                    .font(.headline)

                if let address = item.targetLocationAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct HistoryResultsView: View {
    let item: CaptureHistoryItem
    let onDismiss: () -> Void
    @State private var showingShareOptions = false
    @State private var showingActivityView = false
    @State private var shareContent: [Any]? = nil
    @State private var capturedScreenshot: UIImage? = nil

    init(item: CaptureHistoryItem, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
        print("🏗️ DEBUG: HistoryResultsView init called!")
        print("🏗️ DEBUG: Item ID: \(item.id)")
        print("🏗️ DEBUG: Item timestamp: \(item.timestamp)")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Image section - 60% of screen height
                        ZStack {
                            Image(uiImage: item.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .onAppear {
                                    print("🖼️ DEBUG: Image rendered in HistoryResultsView")
                                }

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

                        // Metadata section - 40% of screen height
                        VStack(spacing: 0) {
                            ScrollView {
                                VStack(spacing: 10) {
                                    // Metadata info using the same component
                                    HistoryMetadataInfoView(
                                        item: item
                                    )

                                    // Results section
                                    if !item.buildingResults.isEmpty || !item.aircraftResults.isEmpty {
                                        VStack(spacing: 10) {
                                            // Building Results
                                            if !item.buildingResults.isEmpty {
                                                LazyVStack(spacing: 10) {
                                                    Section("Buildings & Landmarks") {
                                                        ForEach(item.buildingResults.indices, id: \.self) { index in
                                                            HistoryBuildingResultCard(building: item.buildingResults[index])
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }

                                            // Aircraft Results
                                            if !item.aircraftResults.isEmpty {
                                                LazyVStack(spacing: 10) {
                                                    Section("Aircraft Identified") {
                                                        ForEach(item.aircraftResults.indices, id: \.self) { index in
                                                            HistoryAircraftResultCard(aircraft: item.aircraftResults[index])
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    } else {
                                        // No results message
                                        VStack(spacing: 16) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 48))
                                                .foregroundColor(.gray)

                                            Text("No Objects Identified")
                                                .font(.headline)
                                                .fontWeight(.semibold)

                                            Text("This capture was saved without any identified buildings or aircraft.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6).opacity(0.3))
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                    }

                                    // Add bottom padding for safe area
                                    Spacer(minLength: 20)
                                }
                                .padding(.top, 10)
                            }
                        }
                        .frame(height: geometry.size.height * 0.4)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle("Saved Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        print("❌ DEBUG: Close button tapped in HistoryResultsView")
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
        }
        .onAppear {
            print("✅ DEBUG: HistoryResultsView onAppear called!")
            print("✅ DEBUG: Successfully displaying item: \(item.id)")
        }
        .sheet(isPresented: $showingShareOptions) {
            HistoryCustomShareSheet(
                item: item,
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

    // MARK: - Screenshot Capture for Sharing
    private func captureCurrentViewAsImage() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ Could not get window for screenshot")
            return nil
        }

        // Ensure all views are laid out before capturing
        window.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        let screenshot = renderer.image { context in
            // Use afterScreenUpdates: true to ensure all content is rendered
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        print("📸 Captured full history screenshot of size: \(screenshot.size)")
        print("📸 Window bounds: \(window.bounds)")
        return screenshot
    }
}

// MARK: - History Metadata Info View
struct HistoryMetadataInfoView: View {
    let item: CaptureHistoryItem

    // Calculate target coordinates based on user location, heading, and distance
    private var targetCoordinates: CLLocationCoordinate2D {
        return calculateTargetCoordinates(
            from: item.metadata.gpsCoordinate,
            heading: item.metadata.heading,
            distance: item.estimatedTargetDistance
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
                HistoryLocationCard(
                    title: "Capture Location",
                    address: item.currentLocationAddress,
                    icon: "figure.stand",
                    iconColor: .green,
                    coordinates: item.metadata.gpsCoordinate
                )

                // Target Location Card with calculated coordinates
                HistoryLocationCard(
                    title: "Camera Target",
                    address: item.targetLocationAddress,
                    icon: "camera.viewfinder",
                    iconColor: .blue,
                    distance: item.estimatedTargetDistance,
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
                    HistoryMetadataItem(
                        title: "Heading",
                        value: String(format: "%.0f°", item.metadata.heading),
                        icon: "compass",
                        color: .orange
                    )

                    HistoryMetadataItem(
                        title: "Altitude",
                        value: String(format: "%.0fm", item.metadata.altitude),
                        icon: "mountain.2",
                        color: .brown
                    )

                    HistoryMetadataItem(
                        title: "Zoom",
                        value: String(format: "%.1fx", item.metadata.zoomFactor),
                        icon: "magnifyingglass",
                        color: .purple
                    )

                    HistoryMetadataItem(
                        title: "Field of View",
                        value: String(format: "%.0f°", item.metadata.effectiveFieldOfView),
                        icon: "camera.aperture",
                        color: .indigo
                    )

                    HistoryMetadataItem(
                        title: "Accuracy",
                        value: String(format: "%.0fm", item.metadata.accuracy),
                        icon: "target",
                        color: .red
                    )

                    HistoryMetadataItem(
                        title: "Captured",
                        value: formatTime(item.timestamp),
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

// MARK: - History Location Card Component
struct HistoryLocationCard: View {
    let title: String
    let address: String?
    let icon: String
    let iconColor: Color
    let distance: Double?
    let coordinates: CLLocationCoordinate2D?

    @State private var showingLocationActions = false
    @State private var showingCopiedAlert = false

    init(title: String, address: String?, icon: String, iconColor: Color, distance: Double? = nil, coordinates: CLLocationCoordinate2D? = nil) {
        self.title = title
        self.address = address
        self.icon = icon
        self.iconColor = iconColor
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

                // Add map and copy actions
                if coordinates != nil {
                    Button(action: {
                        showingLocationActions = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
            }

            if let address = address {
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

// MARK: - History Metadata Item Component
struct HistoryMetadataItem: View {
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

// MARK: - History Building Result Card
struct HistoryBuildingResultCard: View {
    let building: Building
    @State private var showingLocationActions = false
    @State private var showingCopiedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with landmark indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Icon based on building type or landmark category
                        if building.isLandmark {
                            landmarkIcon
                                .foregroundColor(landmarkColor)
                        } else {
                            Image(systemName: building.type == .landmark ? "building.2" : "building")
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(building.name)
                                .font(.headline)
                                .lineLimit(2)

                            if building.isLandmark, let category = building.landmarkCategory {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fontWeight(.semibold)
                                }
                            } else {
                                Text(building.type.rawValue.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // Address
                    if let address = building.address {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }

                    // Description
                    if !building.description.isEmpty {
                        Text(building.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(3)
                    }
                }

                Spacer()

                // Distance and metadata with map action
                VStack(alignment: .trailing, spacing: 4) {
                    // Map action button
                    Button(action: {
                        showingLocationActions = true
                    }) {
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                            .font(.title3)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }

                    if let distance = building.distance {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("\(String(format: "%.0f", distance)) m")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    if building.height > 0 {
                        HStack {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text(String(format: "%.0f m", building.height))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    if let year = building.constructionYear {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text("\(year)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    if building.wikipediaURL != nil {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(building.isLandmark ? Color.orange.opacity(0.1) : Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(building.isLandmark ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(10)
        .confirmationDialog("Location Actions", isPresented: $showingLocationActions) {
            Button("Open in Apple Maps") {
                openInAppleMaps()
            }

            Button("Open in Google Maps") {
                openInGoogleMaps()
            }

            Button("Copy Coordinates") {
                copyCoordinates()
            }

            if building.address != nil {
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

    private var landmarkIcon: some View {
        switch building.landmarkCategory {
        case .religiousBuilding:
            return Image(systemName: "building.columns")
        case .government:
            return Image(systemName: "building.columns.fill")
        case .monument:
            return Image(systemName: "figure.stand")
        case .tower:
            return Image(systemName: "antenna.radiowaves.left.and.right")
        case .bridge:
            return Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
        case .architecture:
            return Image(systemName: "building.2.fill")
        case .historicalSite:
            return Image(systemName: "clock.fill")
        case .culturalSite:
            return Image(systemName: "theatermasks")
        case .touristAttraction:
            return Image(systemName: "camera.fill")
        case .museum:
            return Image(systemName: "building.2.crop.circle")
        case .none:
            return Image(systemName: "star.fill")
        }
    }

    private var landmarkColor: Color {
        switch building.landmarkCategory {
        case .religiousBuilding:
            return .purple
        case .government:
            return .blue
        case .monument:
            return .brown
        case .tower:
            return .red
        case .bridge:
            return .cyan
        case .architecture:
            return .orange
        case .historicalSite:
            return .brown
        case .culturalSite:
            return .purple
        case .touristAttraction:
            return .green
        case .museum:
            return .green
        case .none:
            return .yellow
        }
    }

    // MARK: - Location Actions
    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: building.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = building.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps() {
        let urlString = "https://maps.google.com/?daddr=\(building.coordinate.latitude),\(building.coordinate.longitude)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func copyCoordinates() {
        let coordinateString = "\(building.coordinate.latitude), \(building.coordinate.longitude)"
        UIPasteboard.general.string = coordinateString
        showingCopiedAlert = true

        // Also provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        print("📋 Copied building coordinates: \(coordinateString)")
    }

    private func copyAddress() {
        if let address = building.address {
            UIPasteboard.general.string = address
            showingCopiedAlert = true

            // Also provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            print("📋 Copied building address: \(address)")
        }
    }
}

// MARK: - History Aircraft Result Card
struct HistoryAircraftResultCard: View {
    let aircraft: Aircraft
    @State private var showingLocationActions = false
    @State private var showingCopiedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    aircraftHeaderView
                    aircraftTypeView
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    mapActionButton
                    aircraftMetadataView
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
        .confirmationDialog("Aircraft Actions", isPresented: $showingLocationActions) {
            Button("Open in Apple Maps") {
                openInAppleMaps()
            }

            Button("Copy Flight Info") {
                copyFlightInfo()
            }

            Button("Cancel", role: .cancel) { }
        }
        .alert("Copied!", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Flight information copied to clipboard")
        }
    }

    private var aircraftHeaderView: some View {
        HStack {
            Image(systemName: "airplane")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.flightNumber ?? "Unknown Flight")
                    .font(.headline)
                    .lineLimit(1)

                if let airline = aircraft.airline {
                    Text(airline)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var aircraftTypeView: some View {
        Group {
            if !aircraft.aircraftType.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(aircraft.aircraftType)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var mapActionButton: some View {
        Button(action: {
            showingLocationActions = true
        }) {
            Image(systemName: "map")
                .foregroundColor(.blue)
                .font(.title3)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private var aircraftMetadataView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Image(systemName: "arrow.up")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("\(String(format: "%.0f", aircraft.altitude)) ft")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("\(String(format: "%.0f", aircraft.speed)) kts")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if let distance = aircraft.distance {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(String(format: "%.1f", distance)) km")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Aircraft Actions
    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: aircraft.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = aircraft.flightNumber ?? "Aircraft"
        mapItem.openInMaps()
    }

    private func copyFlightInfo() {
        var info = aircraft.flightNumber ?? "Unknown Flight"
        if let airline = aircraft.airline {
            info += " - \(airline)"
        }

        UIPasteboard.general.string = info
        showingCopiedAlert = true

        // Also provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        print("📋 Copied flight info: \(info)")
    }
}

struct ErrorView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Error: No item selected")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Something went wrong while loading the capture details.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Close") {
                onDismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

// MARK: - History Custom Share Sheet
struct HistoryCustomShareSheet: View {
    let item: CaptureHistoryItem
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

                    Text("Share History Item")
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
                        // Framed Option (Screenshot)
                        Button(action: {
                            selectedFrameOption = .framed
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(height: 60)

                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(height: 8)
                                            .cornerRadius(2)
                                    }
                                }

                                Text("Full View")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("Screenshot with UI")
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

                                Text("Photo only")
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
                    // Standard iOS Sharing
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

    // MARK: - Sharing Actions
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
                                    self.successMessage = "History item saved to your library!"
                                    self.showingSuccess = true
                                } else {
                                    self.errorMessage = "Failed to save: \(error?.localizedDescription ?? "Unknown error")"
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

    private func getSelectedImageAsync() async -> UIImage {
        switch selectedFrameOption {
        case .original:
            return item.image
        case .framed:
            // Use actual screenshot instead of programmatic frame
            if let screenshot = preCapuredScreenshot {
                print("📸 Using captured screenshot for history sharing")
                return screenshot
            } else {
                print("⚠️ Screenshot failed, falling back to original image")
                return item.image
            }
        }
    }

    private func generateShareText() -> String {
        var shareText = "📸 ShootVeil History\n"

        if let target = item.targetLocationAddress {
            shareText += "📍 \(target)\n"
        }

        if item.estimatedTargetDistance > 0 {
            shareText += "📏 \(String(format: "%.0f", item.estimatedTargetDistance))m away\n"
        }

        if !item.buildingResults.isEmpty {
            shareText += "🏢 \(item.buildingResults.count) buildings identified\n"
        }

        if !item.aircraftResults.isEmpty {
            shareText += "✈️ \(item.aircraftResults.count) aircraft spotted\n"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        shareText += "🕒 Captured: \(formatter.string(from: item.timestamp))\n"

        shareText += "\n🚀 Get the app: shootveil.ai\n#ShootVeil #AICamera"

        return shareText
    }
}

// MARK: - Enhanced Capture History Manager with Image Persistence
class CaptureHistoryManager: ObservableObject {
    @Published var items: [CaptureHistoryItem] = []
    private let storageKey = "CaptureHistoryItems"

    init() {
        loadHistory()
    }

    func addCapture(
        image: UIImage,
        metadata: CaptureMetadata,
        buildingResults: [Building],
        aircraftResults: [Aircraft],
        currentLocationAddress: String?,
        targetLocationAddress: String?,
        estimatedTargetDistance: Double
    ) {
        let item = CaptureHistoryItem(
            id: UUID(),
            timestamp: Date(),
            image: image,
            metadata: metadata,
            buildingResults: buildingResults,
            aircraftResults: aircraftResults,
            currentLocationAddress: currentLocationAddress,
            targetLocationAddress: targetLocationAddress,
            estimatedTargetDistance: estimatedTargetDistance
        )

        // Save image to documents directory
        saveImageToDocuments(image: image, id: item.id)

        items.insert(item, at: 0) // Add to beginning
        saveHistory()
        print("📝 Added capture to history. Total items: \(items.count)")
    }

    func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("📂 No saved history found")
            return
        }

        do {
            let decoder = JSONDecoder()
            let persistentItems = try decoder.decode([PersistentCaptureItem].self, from: data)

            // Convert persistent items to full items and load images
            items = persistentItems.compactMap { persistentItem in
                let image = loadImageFromDocuments(id: persistentItem.id) ?? createPlaceholderImage(for: persistentItem)
                return CaptureHistoryItem(
                    id: persistentItem.id,
                    timestamp: persistentItem.timestamp,
                    image: image,
                    metadata: persistentItem.metadata,
                    buildingResults: persistentItem.buildingResults,
                    aircraftResults: persistentItem.aircraftResults,
                    currentLocationAddress: persistentItem.currentLocationAddress,
                    targetLocationAddress: persistentItem.targetLocationAddress,
                    estimatedTargetDistance: persistentItem.estimatedTargetDistance
                )
            }

            print("📖 Loaded \(items.count) items from history")
        } catch {
            print("❌ Failed to load history: \(error)")
            items = []
        }
    }

    private func saveHistory() {
        // Convert items to persistent format (without images)
        let persistentItems = items.map { $0.toPersistentItem() }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(persistentItems)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 Saved \(persistentItems.count) items to history")
        } catch {
            print("❌ Failed to save history: \(error)")
        }
    }

    // MARK: - Image Persistence Methods
    private func saveImageToDocuments(image: UIImage, id: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent("\(id.uuidString).jpg")

        do {
            try data.write(to: imagePath)
            print("💾 Saved image for capture \(id)")
        } catch {
            print("❌ Failed to save image: \(error)")
        }
    }

    private func loadImageFromDocuments(id: UUID) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent("\(id.uuidString).jpg")

        guard FileManager.default.fileExists(atPath: imagePath.path) else {
            print("⚠️ Image file not found for capture \(id)")
            return nil
        }

        return UIImage(contentsOfFile: imagePath.path)
    }

    private func deleteImageFromDocuments(id: UUID) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent("\(id.uuidString).jpg")

        try? FileManager.default.removeItem(at: imagePath)
    }

    // Create an enhanced placeholder image with capture info
    private func createPlaceholderImage(for item: PersistentCaptureItem) -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // Create a gradient background based on capture type
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors: [CGColor]

            if !item.aircraftResults.isEmpty {
                // Aircraft gradient (orange/blue)
                colors = [
                    UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0).cgColor,
                    UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
                ]
            } else if !item.buildingResults.isEmpty {
                // Building gradient (blue/purple)
                colors = [
                    UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0).cgColor,
                    UIColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0).cgColor
                ]
            } else {
                // Default gradient (gray)
                colors = [
                    UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0).cgColor,
                    UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0).cgColor
                ]
            }

            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) else { return }

            cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            // Add "Image Missing" text
            let titleText = "📷 Image Missing"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let titleAttributedString = NSAttributedString(string: titleText, attributes: titleAttributes)
            let titleSize = titleAttributedString.size()
            let titleRect = CGRect(
                x: (size.width - titleSize.width) / 2,
                y: (size.height - titleSize.height) / 2 - 30,
                width: titleSize.width,
                height: titleSize.height
            )

            titleAttributedString.draw(in: titleRect)

            // Add count text
            let countText: String
            if !item.aircraftResults.isEmpty {
                countText = "\(item.aircraftResults.count) Aircraft Identified"
            } else if !item.buildingResults.isEmpty {
                countText = "\(item.buildingResults.count) Building\(item.buildingResults.count == 1 ? "" : "s") Identified"
            } else {
                countText = "No Objects Identified"
            }

            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]

            let countAttributedString = NSAttributedString(string: countText, attributes: countAttributes)
            let countSize = countAttributedString.size()
            let countRect = CGRect(
                x: (size.width - countSize.width) / 2,
                y: (size.height - countSize.height) / 2 + 10,
                width: countSize.width,
                height: countSize.height
            )

            countAttributedString.draw(in: countRect)
        }
    }

    func sortByDate() {
        items.sort { $0.timestamp > $1.timestamp }
    }

    func sortByLocation() {
        items.sort { ($0.targetLocationAddress ?? "") < ($1.targetLocationAddress ?? "") }
    }

    func clearAll() {
        // Delete all saved images
        for item in items {
            deleteImageFromDocuments(id: item.id)
        }

        items.removeAll()
        saveHistory()
        print("🗑️ Cleared all history items and images")
    }

    func sortByType() {
        items.sort { item1, item2 in
            let type1 = item1.aircraftResults.isEmpty ? "building" : "aircraft"
            let type2 = item2.aircraftResults.isEmpty ? "building" : "aircraft"
            return type1 < type2
        }
    }

    func deleteItem(_ item: CaptureHistoryItem) {
        deleteImageFromDocuments(id: item.id)
        items.removeAll { $0.id == item.id }
        saveHistory()
        print("🗑️ Deleted history item and image: \(item.id)")
    }
}

// MARK: - Data Models (Updated)
struct CaptureHistoryItem: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let image: UIImage
    let metadata: CaptureMetadata
    let buildingResults: [Building]
    let aircraftResults: [Aircraft]
    let currentLocationAddress: String?
    let targetLocationAddress: String?
    let estimatedTargetDistance: Double

    // Equatable conformance
    static func == (lhs: CaptureHistoryItem, rhs: CaptureHistoryItem) -> Bool {
        return lhs.id == rhs.id
    }

    var shareText: String {
        var text = "📸 ShootVeil Smart Capture\n\n"

        if let target = targetLocationAddress {
            text += "🎯 Target: \(target)\n"
        }
        if let current = currentLocationAddress {
            text += "📍 Location: \(current)\n"
        }

        text += "🧭 Heading: \(String(format: "%.0f", metadata.heading))°\n"
        text += "📏 Distance: \(String(format: "%.0f", estimatedTargetDistance))m\n\n"

        if !buildingResults.isEmpty {
            text += "🏢 Buildings: \(buildingResults.map { $0.name }.joined(separator: ", "))\n"
        }

        if !aircraftResults.isEmpty {
            text += "✈️ Aircraft: \(aircraftResults.compactMap { $0.flightNumber }.joined(separator: ", "))\n"
        }

        text += "\n🚀 Get the app: shootveil.ai\n#ShootVeil #AICamera"

        return text
    }

    func toPersistentItem() -> PersistentCaptureItem {
        return PersistentCaptureItem(
            id: id,
            timestamp: timestamp,
            metadata: metadata,
            buildingResults: buildingResults,
            aircraftResults: aircraftResults,
            currentLocationAddress: currentLocationAddress,
            targetLocationAddress: targetLocationAddress,
            estimatedTargetDistance: estimatedTargetDistance
        )
    }
}

// MARK: - Persistent Capture Item (for storage without images)
struct PersistentCaptureItem: Codable {
    let id: UUID
    let timestamp: Date
    let metadata: CaptureMetadata
    let buildingResults: [Building]
    let aircraftResults: [Aircraft]
    let currentLocationAddress: String?
    let targetLocationAddress: String?
    let estimatedTargetDistance: Double
}

#Preview {
    HistoryView()
        .environmentObject(CaptureHistoryManager())
}
