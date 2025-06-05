//
//  UnvealFeedbackView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/3/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct UnvealFeedbackView: View {
    let unvealResult: UnvealResult
    let originalImage: UIImage
    let onFeedbackSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var unvealCalculator = UnvealCalculator.shared

    @State private var actualLocationName = ""
    @State private var actualLocation: CLLocationCoordinate2D?
    @State private var userNotes = ""
    @State private var showingLocationPicker = false
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var mapRegion: MKCoordinateRegion
    @State private var selectedLocation: SelectedLocation?

    init(unvealResult: UnvealResult, originalImage: UIImage, onFeedbackSubmitted: @escaping () -> Void) {
        self.unvealResult = unvealResult
        self.originalImage = originalImage
        self.onFeedbackSubmitted = onFeedbackSubmitted

        // Initialize map region around calculated location
        self._mapRegion = State(initialValue: MKCoordinateRegion(
            center: unvealResult.targetCoordinates,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView

                    // Original calculation summary
                    calculationSummaryView

                    // Photo for reference
                    photoReferenceView

                    // Feedback form
                    feedbackFormView

                    // Map for location correction
                    locationCorrectionView

                    // Submit button
                    submitButtonView

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Help Train Unveal v1.0")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Feedback Submitted!", isPresented: $showingSuccess) {
            Button("Done") {
                onFeedbackSubmitted()
                dismiss()
            }
        } message: {
            Text("Thank you! Your feedback helps improve Unveal v1.0 calculations.")
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(.purple)

            Text("Help Train Unveal v1.0")
                .font(.title2)
                .fontWeight(.bold)

            Text("Tell us what you actually photographed to improve our AI calculations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 10)
    }

    // MARK: - Calculation Summary
    private var calculationSummaryView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calculator")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Unveal v1.0 Calculated")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(spacing: 8) {
                calculationRow(
                    icon: "location",
                    title: "Target Location",
                    value: String(format: "%.6f, %.6f",
                                unvealResult.targetCoordinates.latitude,
                                unvealResult.targetCoordinates.longitude)
                )

                calculationRow(
                    icon: "chart.bar",
                    title: "Confidence",
                    value: String(format: "%.1f%%", unvealResult.confidence * 100)
                )

                calculationRow(
                    icon: "ruler",
                    title: "Estimated Distance",
                    value: String(format: "%.0fm", unvealResult.calculation.estimatedDistance)
                )

                calculationRow(
                    icon: "compass",
                    title: "Bearing",
                    value: String(format: "%.0f°", unvealResult.calculation.heading)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }

    private func calculationRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.caption)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Photo Reference
    private var photoReferenceView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("Your Photo")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Image(uiImage: originalImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Feedback Form
    private var feedbackFormView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text("What Did You Actually Photograph?")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Location/Building Name")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g., Empire State Building, 123 Main St", text: $actualLocationName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Notes (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g., Top floor visible, partially obscured", text: $userNotes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...5)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Location Correction
    private var locationCorrectionView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(.red)
                    .font(.title3)
                Text("Correct the Location")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("Tap on the map to mark the actual location you photographed")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Interactive Map
            Map(coordinateRegion: $mapRegion, annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    VStack {
                        Image(systemName: annotation.isCalculated ? "target" : "mappin.circle.fill")
                            .foregroundColor(annotation.isCalculated ? .blue : .red)
                            .font(.title2)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                            )

                        Text(annotation.title)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(height: 250)
            .cornerRadius(12)
            .onTapGesture { location in
                // Convert tap location to coordinates (simplified)
                // In a real app, you'd use proper coordinate conversion
                handleMapTap(at: location)
            }

            if let selectedLocation = selectedLocation {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("Actual location marked: \(String(format: "%.6f, %.6f", selectedLocation.coordinate.latitude, selectedLocation.coordinate.longitude))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Clear") {
                        self.selectedLocation = nil
                        actualLocation = nil
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }

    private var mapAnnotations: [MapAnnotationItem] {
        var annotations: [MapAnnotationItem] = []

        // Calculated location
        annotations.append(MapAnnotationItem(
            id: "calculated",
            coordinate: unvealResult.targetCoordinates,
            title: "Calculated",
            isCalculated: true
        ))

        // Actual location (if selected)
        if let actual = selectedLocation {
            annotations.append(MapAnnotationItem(
                id: "actual",
                coordinate: actual.coordinate,
                title: "Actual",
                isCalculated: false
            ))
        }

        return annotations
    }

    // MARK: - Submit Button
    private var submitButtonView: some View {
        VStack(spacing: 12) {
            Button(action: submitFeedback) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                    }

                    Text(isSubmitting ? "Training Unveal v1.0..." : "Submit Training Data")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSubmit ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canSubmit || isSubmitting)

            Text("Your feedback helps improve location calculations for everyone!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helper Properties
    private var canSubmit: Bool {
        !actualLocationName.isEmpty && actualLocation != nil
    }

    // MARK: - Helper Methods
    private func handleMapTap(at location: CGPoint) {
        // Simplified coordinate calculation
        // In a real implementation, you'd convert screen coordinates to map coordinates
        let coordinate = CLLocationCoordinate2D(
            latitude: unvealResult.targetCoordinates.latitude + Double.random(in: -0.005...0.005),
            longitude: unvealResult.targetCoordinates.longitude + Double.random(in: -0.005...0.005)
        )

        selectedLocation = SelectedLocation(coordinate: coordinate)
        actualLocation = coordinate

        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func submitFeedback() {
        guard let actualLocation = actualLocation else { return }

        isSubmitting = true

        // Simulate processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            unvealCalculator.collectUserFeedback(
                for: unvealResult,
                actualLocation: actualLocation,
                actualName: actualLocationName,
                userNotes: userNotes.isEmpty ? nil : userNotes
            )

            isSubmitting = false
            showingSuccess = true

            // Success haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
}

// MARK: - Supporting Data Models
struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isCalculated: Bool
}

struct SelectedLocation {
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview
#Preview {
    UnvealFeedbackView(
        unvealResult: UnvealResult(
            id: UUID(),
            calculation: UnvealCalculation(
                userLocation: CLLocationCoordinate2D(latitude: 40.7589, longitude: -73.9851),
                heading: 45.0,
                estimatedDistance: 500.0,
                zoomFactor: 2.0,
                fieldOfView: 60.0,
                altitude: 10.0,
                deviceOrientation: "portrait",
                timestamp: Date(),
                version: "1.0"
            ),
            targetCoordinates: CLLocationCoordinate2D(latitude: 40.7614, longitude: -73.9776),
            confidence: 0.85,
            calculationMethod: "bearing_distance_v1.0",
            metadata: [:]
        ),
        originalImage: UIImage(systemName: "photo") ?? UIImage(),
        onFeedbackSubmitted: {}
    )
}
