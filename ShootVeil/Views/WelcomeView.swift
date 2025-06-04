//
//  WelcomeView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // App Icon and Title
                VStack(spacing: 20) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("ShootVeil")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Intelligent Object Identification")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Instructions
                VStack(spacing: 25) {
                    InstructionRow(
                        icon: "camera.fill",
                        title: "Capture",
                        description: "Point your camera at buildings or aircraft and take a photo"
                    )

                    InstructionRow(
                        icon: "hand.tap.fill",
                        title: "Tap to Identify",
                        description: "Tap on buildings in your photo to identify them"
                    )

                    InstructionRow(
                        icon: "airplane",
                        title: "Auto-Detect",
                        description: "Aircraft are automatically identified using your location"
                    )
                }
                .padding(.horizontal, 30)

                Spacer()

                // Continue Button
                Button(action: onContinue) {
                    HStack {
                        Text("Get Started")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(Color.white)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }

                Text("Works with buildings, landmarks, and aircraft across the United States")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
