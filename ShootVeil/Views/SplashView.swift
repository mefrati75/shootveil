//
//  SplashView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var crosshairRotation: Double = 0.0

    let onAnimationComplete: () -> Void

    var body: some View {
        ZStack {
            // Background gradient matching app theme
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.6, blue: 1.0),  // Blue
                    Color(red: 0.5, green: 0.3, blue: 0.9)   // Purple
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo with animated camera viewfinder
                ZStack {
                    // Outer viewfinder circle
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    // Inner crosshair circle
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(crosshairRotation))

                    // Crosshair lines
                    Group {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 40, height: 3)
                            .cornerRadius(1.5)

                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3, height: 40)
                            .cornerRadius(1.5)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotationEffect(.degrees(crosshairRotation))

                    // Center dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    // Tech corner elements
                    ForEach(0..<4, id: \.self) { index in
                        TechCorner()
                            .rotationEffect(.degrees(Double(index * 90)))
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity * 0.7)
                    }
                }
                .frame(width: 140, height: 140)

                // App name and subtitle
                VStack(spacing: 16) {
                    Text("ShootVeil")
                        .font(.system(size: 48, weight: .heavy, design: .default))
                        .foregroundColor(.white)
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.8)

                    Text("Intelligent Object Identification")
                        .font(.system(size: 20, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.8)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .opacity(showContent ? 1.0 : 0.0)

                    Text("Initializing AI Camera...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(showContent ? 1.0 : 0.0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startSplashAnimation()
        }
    }

    private func startSplashAnimation() {
        // Initial logo animation
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Crosshair rotation animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            crosshairRotation = 360.0
        }

        // Content fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }

        // Complete animation after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                logoOpacity = 0.0
                showContent = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onAnimationComplete()
            }
        }
    }
}

// MARK: - Tech Corner Component
struct TechCorner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 16)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 14, height: 2)
            }
            Spacer()
        }
        .frame(width: 60, height: 60)
        .offset(x: -30, y: -30)
    }
}

// MARK: - Preview
#Preview {
    SplashView {
        print("Splash animation completed")
    }
}
