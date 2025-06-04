//
//  ShareManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import UIKit
import CoreLocation
import SwiftUI

@MainActor
class ShareManager: ObservableObject {
    static let shared = ShareManager()
    private init() {}

    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""

    // MARK: - Async Frame Creation (Optimized)
    func createFramedPhotoAsync(
        originalImage: UIImage,
        metadata: CaptureMetadata,
        buildings: [Building],
        aircraft: [Aircraft],
        currentAddress: String?,
        targetAddress: String?,
        distance: Double
    ) async -> UIImage {

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let framedImage = ShareManager.createOptimizedFrame(
                    originalImage: originalImage,
                    metadata: metadata,
                    buildings: buildings,
                    aircraft: aircraft,
                    currentAddress: currentAddress,
                    targetAddress: targetAddress,
                    distance: distance
                )
                continuation.resume(returning: framedImage)
            }
        }
    }

    // MARK: - Optimized Frame Creation with 60/40 Layout (Beautiful Design with Icons)
    nonisolated private static func createOptimizedFrame(
        originalImage: UIImage,
        metadata: CaptureMetadata,
        buildings: [Building],
        aircraft: [Aircraft],
        currentAddress: String?,
        targetAddress: String?,
        distance: Double
    ) -> UIImage {

        let imageSize = originalImage.size
        // 40% of total height for metadata section (60/40 ratio)
        let metadataHeight: CGFloat = imageSize.height * 0.67 // 40% of total = 2/3 of image height
        let totalHeight = imageSize.height + metadataHeight

        // High quality rendering for share cards
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(originalImage.scale, 3.0) // Higher quality for sharing
        format.opaque = true
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize.width, height: totalHeight), format: format)

        return renderer.image { context in
            // 1. Draw original image - 60% of total
            originalImage.draw(at: .zero)

            // 2. Beautiful gradient background for metadata section - 40% of total
            let metadataRect = CGRect(x: 0, y: imageSize.height, width: imageSize.width, height: metadataHeight)

            // Create gradient background
            let gradientColors = [UIColor.systemBackground.cgColor, UIColor.systemGray6.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: [0.0, 1.0])!
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: imageSize.height), end: CGPoint(x: 0, y: totalHeight), options: [])

            // 3. Elegant border between sections
            let borderRect = CGRect(x: 0, y: imageSize.height - 2, width: imageSize.width, height: 4)
            UIColor.systemBlue.setFill()
            context.fill(borderRect)

            // 4. Content layout with proper spacing
            let padding = imageSize.width * 0.05
            let contentStartY = imageSize.height + padding * 1.5
            let cardPadding = padding * 0.8
            let iconSize: CGFloat = imageSize.width * 0.06

            // Responsive font sizing
            let titleFont = UIFont.systemFont(ofSize: imageSize.width * 0.048, weight: .bold)
            let headerFont = UIFont.systemFont(ofSize: imageSize.width * 0.032, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: imageSize.width * 0.026, weight: .medium)
            let captionFont = UIFont.systemFont(ofSize: imageSize.width * 0.020, weight: .regular)

            // Beautiful color scheme
            let primaryColor = UIColor.label
            let secondaryColor = UIColor.secondaryLabel
            let accentColor = UIColor.systemBlue
            let orangeColor = UIColor.systemOrange
            let cardBackgroundColor = UIColor.systemBackground

            var yPos = contentStartY

            // Header with app branding and beautiful styling
            let headerRect = CGRect(x: padding, y: yPos, width: imageSize.width - (padding * 2), height: titleFont.lineHeight + padding)
            cardBackgroundColor.setFill()
            context.fill(headerRect)

            // Add subtle shadow to header
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.1).cgColor)
            let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 8)
            UIColor.white.setFill()
            headerPath.fill()
            context.cgContext.setShadow(offset: .zero, blur: 0)

            // App title with icon
            let appIcon = "📸"
            let appIconAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: titleFont.pointSize * 1.2)]
            appIcon.draw(at: CGPoint(x: padding + cardPadding, y: yPos + cardPadding * 0.5), withAttributes: appIconAttrs)

            let appTitle = "ShootVeil AI Camera"
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: accentColor]
            appTitle.draw(at: CGPoint(x: padding + cardPadding + iconSize * 1.5, y: yPos + cardPadding * 0.5), withAttributes: titleAttrs)

            yPos += headerRect.height + padding

            // Location Information Card
            if currentAddress != nil || targetAddress != nil {
                let locationCardHeight = bodyFont.lineHeight * 6 + cardPadding * 2
                let locationRect = CGRect(x: padding, y: yPos, width: imageSize.width - (padding * 2), height: locationCardHeight)

                // Beautiful card background
                let locationPath = UIBezierPath(roundedRect: locationRect, cornerRadius: 12)
                cardBackgroundColor.setFill()
                locationPath.fill()

                // Card border
                UIColor.systemBlue.withAlphaComponent(0.3).setStroke()
                locationPath.lineWidth = 1
                locationPath.stroke()

                // Location header with icon
                let locationIconSize: CGFloat = headerFont.pointSize
                drawSFSymbol("location.circle.fill", at: CGPoint(x: padding + cardPadding, y: yPos + cardPadding), size: locationIconSize, color: accentColor, in: context)

                let locationHeaderAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: primaryColor]
                "Location Information".draw(at: CGPoint(x: padding + cardPadding + locationIconSize + 8, y: yPos + cardPadding), withAttributes: locationHeaderAttrs)

                var locationY = yPos + cardPadding + headerFont.lineHeight + 8

                // Current location
                if let current = currentAddress {
                    drawSFSymbol("figure.stand", at: CGPoint(x: padding + cardPadding + 8, y: locationY), size: bodyFont.pointSize, color: UIColor.systemGreen, in: context)

                    let currentLabelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: primaryColor]
                    "Your Location".draw(at: CGPoint(x: padding + cardPadding + 32, y: locationY), withAttributes: currentLabelAttrs)
                    locationY += bodyFont.lineHeight + 2

                    let currentAddressAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: secondaryColor]
                    let shortCurrent = String(current.prefix(45))
                    shortCurrent.draw(at: CGPoint(x: padding + cardPadding + 32, y: locationY), withAttributes: currentAddressAttrs)
                    locationY += captionFont.lineHeight + 8
                }

                // Target location
                if let target = targetAddress {
                    drawSFSymbol("camera.viewfinder", at: CGPoint(x: padding + cardPadding + 8, y: locationY), size: bodyFont.pointSize, color: accentColor, in: context)

                    let targetLabelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: primaryColor]
                    "Camera Target".draw(at: CGPoint(x: padding + cardPadding + 32, y: locationY), withAttributes: targetLabelAttrs)
                    locationY += bodyFont.lineHeight + 2

                    let targetAddressAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: secondaryColor]
                    let shortTarget = String(target.prefix(45))
                    shortTarget.draw(at: CGPoint(x: padding + cardPadding + 32, y: locationY), withAttributes: targetAddressAttrs)

                    if distance > 0 {
                        let distanceText = distance >= 1000 ?
                            String(format: "%.1fkm away", distance / 1000) :
                            "\(Int(distance))m away"
                        let distanceSize = distanceText.size(withAttributes: [.font: captionFont])
                        let distanceRect = CGRect(
                            x: locationRect.maxX - cardPadding - distanceSize.width - 12,
                            y: locationY - 2,
                            width: distanceSize.width + 12,
                            height: captionFont.lineHeight + 4
                        )

                        orangeColor.withAlphaComponent(0.1).setFill()
                        UIBezierPath(roundedRect: distanceRect, cornerRadius: 8).fill()

                        let distanceAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: orangeColor]
                        distanceText.draw(at: CGPoint(x: distanceRect.minX + 6, y: distanceRect.minY + 2), withAttributes: distanceAttrs)
                    }
                }

                yPos += locationCardHeight + padding
            }

            // Results Card (Buildings & Aircraft)
            if !buildings.isEmpty || !aircraft.isEmpty {
                let resultsCardHeight = headerFont.lineHeight + bodyFont.lineHeight * 4 + cardPadding * 2
                let resultsRect = CGRect(x: padding, y: yPos, width: imageSize.width - (padding * 2), height: resultsCardHeight)

                // Beautiful results card
                let resultsPath = UIBezierPath(roundedRect: resultsRect, cornerRadius: 12)
                cardBackgroundColor.setFill()
                resultsPath.fill()

                // Card border with accent color
                orangeColor.withAlphaComponent(0.3).setStroke()
                resultsPath.lineWidth = 1
                resultsPath.stroke()

                // Results header
                let resultsIconSize: CGFloat = headerFont.pointSize
                drawSFSymbol("brain.head.profile", at: CGPoint(x: padding + cardPadding, y: yPos + cardPadding), size: resultsIconSize, color: orangeColor, in: context)

                let resultsHeaderAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: primaryColor]
                "AI Analysis Results".draw(at: CGPoint(x: padding + cardPadding + resultsIconSize + 8, y: yPos + cardPadding), withAttributes: resultsHeaderAttrs)

                var resultsY = yPos + cardPadding + headerFont.lineHeight + 8

                // Buildings
                if !buildings.isEmpty {
                    drawSFSymbol("building.2.fill", at: CGPoint(x: padding + cardPadding + 8, y: resultsY), size: bodyFont.pointSize, color: orangeColor, in: context)

                    let buildingText = "\(buildings.count) Building\(buildings.count > 1 ? "s" : "") Identified"
                    let buildingAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: primaryColor]
                    buildingText.draw(at: CGPoint(x: padding + cardPadding + 32, y: resultsY), withAttributes: buildingAttrs)
                    resultsY += bodyFont.lineHeight + 4

                    // Show first building name
                    if let firstBuilding = buildings.first {
                        let buildingNameAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: secondaryColor]
                        let shortName = String(firstBuilding.name.prefix(40))
                        shortName.draw(at: CGPoint(x: padding + cardPadding + 32, y: resultsY), withAttributes: buildingNameAttrs)
                        resultsY += captionFont.lineHeight + 8
                    }
                }

                // Aircraft
                if !aircraft.isEmpty {
                    drawSFSymbol("airplane", at: CGPoint(x: padding + cardPadding + 8, y: resultsY), size: bodyFont.pointSize, color: accentColor, in: context)

                    let aircraftText = "\(aircraft.count) Aircraft Spotted"
                    let aircraftAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: primaryColor]
                    aircraftText.draw(at: CGPoint(x: padding + cardPadding + 32, y: resultsY), withAttributes: aircraftAttrs)
                    resultsY += bodyFont.lineHeight + 4

                    // Show first aircraft info
                    if let firstAircraft = aircraft.first {
                        let flightInfo = firstAircraft.flightNumber ?? "Unknown Flight"
                        let flightAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: secondaryColor]
                        flightInfo.draw(at: CGPoint(x: padding + cardPadding + 32, y: resultsY), withAttributes: flightAttrs)
                    }
                }

                yPos += resultsCardHeight + padding
            }

            // Technical Details Card
            let techCardHeight = headerFont.lineHeight + bodyFont.lineHeight * 2 + cardPadding * 2
            let techRect = CGRect(x: padding, y: yPos, width: imageSize.width - (padding * 2), height: techCardHeight)

            let techPath = UIBezierPath(roundedRect: techRect, cornerRadius: 12)
            cardBackgroundColor.setFill()
            techPath.fill()

            UIColor.systemGray4.setStroke()
            techPath.lineWidth = 1
            techPath.stroke()

            // Tech header
            let techIconSize: CGFloat = headerFont.pointSize
            drawSFSymbol("gear.badge", at: CGPoint(x: padding + cardPadding, y: yPos + cardPadding), size: techIconSize, color: UIColor.systemGray, in: context)

            let techHeaderAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: primaryColor]
            "Capture Details".draw(at: CGPoint(x: padding + cardPadding + techIconSize + 8, y: yPos + cardPadding), withAttributes: techHeaderAttrs)

            let techY = yPos + cardPadding + headerFont.lineHeight + 8

            // Technical metadata in beautiful icon format
            let leftColumnX = padding + cardPadding + 8
            let rightColumnX = imageSize.width * 0.52
            let metadataAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: secondaryColor]

            // Left column
            drawSFSymbol("location.north.circle", at: CGPoint(x: leftColumnX, y: techY), size: captionFont.pointSize, color: UIColor.systemBlue, in: context)
            "\(String(format: "%.0f°", metadata.heading))".draw(at: CGPoint(x: leftColumnX + 24, y: techY), withAttributes: metadataAttrs)

            drawSFSymbol("mountain.2", at: CGPoint(x: leftColumnX, y: techY + captionFont.lineHeight + 4), size: captionFont.pointSize, color: UIColor.systemBrown, in: context)
            "\(String(format: "%.0fm", metadata.altitude))".draw(at: CGPoint(x: leftColumnX + 24, y: techY + captionFont.lineHeight + 4), withAttributes: metadataAttrs)

            // Right column
            drawSFSymbol("magnifyingglass", at: CGPoint(x: rightColumnX, y: techY), size: captionFont.pointSize, color: UIColor.systemPurple, in: context)
            "\(String(format: "%.1fx", metadata.zoomFactor))".draw(at: CGPoint(x: rightColumnX + 24, y: techY), withAttributes: metadataAttrs)

            drawSFSymbol("clock", at: CGPoint(x: rightColumnX, y: techY + captionFont.lineHeight + 4), size: captionFont.pointSize, color: UIColor.systemGreen, in: context)
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.string(from: metadata.timestamp).draw(at: CGPoint(x: rightColumnX + 24, y: techY + captionFont.lineHeight + 4), withAttributes: metadataAttrs)

            // Beautiful bottom branding
            let bottomY = metadataRect.maxY - padding - bodyFont.lineHeight - 8
            let brandRect = CGRect(x: padding, y: bottomY, width: imageSize.width - (padding * 2), height: bodyFont.lineHeight + 8)

            accentColor.withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: brandRect, cornerRadius: 8).fill()

            drawSFSymbol("rocket.fill", at: CGPoint(x: padding + cardPadding, y: bottomY + 4), size: bodyFont.pointSize, color: accentColor, in: context)

            let brandText = "Get the app: shootveil.ai"
            let brandAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: accentColor]
            brandText.draw(at: CGPoint(x: padding + cardPadding + bodyFont.pointSize + 8, y: bottomY + 4), withAttributes: brandAttrs)
        }
    }

    // MARK: - Helper function to draw SF Symbols (Fixed)
    nonisolated private static func drawSFSymbol(_ symbolName: String, at point: CGPoint, size: CGFloat, color: UIColor, in context: UIGraphicsImageRendererContext) {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .medium)
        if let symbol = UIImage(systemName: symbolName, withConfiguration: config) {
            // Create colored version of the symbol
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size + 4, height: size + 4))
            let coloredSymbol = renderer.image { _ in
                color.setFill()
                symbol.draw(at: CGPoint(x: 2, y: 2), blendMode: .normal, alpha: 1.0)
            }

            // Draw the colored symbol at the specified point
            coloredSymbol.draw(at: point)
        } else {
            // Fallback to emoji if SF Symbol fails
            let fallbackEmoji = getFallbackEmoji(for: symbolName)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size),
                .foregroundColor: color
            ]
            fallbackEmoji.draw(at: point, withAttributes: attrs)
        }
    }

    // MARK: - Fallback emoji mapping
    nonisolated private static func getFallbackEmoji(for symbolName: String) -> String {
        switch symbolName {
        case "location.circle.fill": return "📍"
        case "figure.stand": return "👤"
        case "camera.viewfinder": return "📷"
        case "brain.head.profile": return "🧠"
        case "building.2.fill": return "🏢"
        case "airplane": return "✈️"
        case "gear.badge": return "⚙️"
        case "location.north.circle": return "🧭"
        case "mountain.2": return "⛰️"
        case "magnifyingglass": return "🔍"
        case "clock": return "⏰"
        case "rocket.fill": return "🚀"
        default: return "●"
        }
    }

    // MARK: - Generate Share Content with Framed Photo Option
    func generateShareContent(
        originalImage: UIImage,
        metadata: CaptureMetadata,
        buildings: [Building],
        aircraft: [Aircraft],
        targetAddress: String?,
        distance: Double
    ) -> (UIImage, String) {

        // Just return the original image with descriptive text
        var shareText = "📸 ShootVeil Smart Capture"

        if let target = targetAddress {
            shareText += "\n📍 \(String(target.prefix(60)))"
        }

        if distance > 0 {
            shareText += "\n📏 \(Int(distance))m away"
        }

        if !buildings.isEmpty {
            shareText += "\n🏢 \(buildings.count) building\(buildings.count > 1 ? "s" : "") identified"
        }

        if !aircraft.isEmpty {
            shareText += "\n✈️ \(aircraft.count) aircraft spotted"
        }

        shareText += "\n\n🚀 Get the app: shootveil.ai"
        shareText += "\n#ShootVeil #AICamera"

        return (originalImage, shareText)
    }
}
