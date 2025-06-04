//
//  SubscriptionManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/2/25.
//

import Foundation
import SwiftUI

// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var currentTier: SubscriptionTier = .adSupported
    @Published var usageThisMonth: Int = 0
    @Published var subscriptionExpiryDate: Date?
    @Published var isSubscriptionActive: Bool = false

    // Usage tracking
    @AppStorage("monthly_usage_count") private var monthlyUsageCount: Int = 0
    @AppStorage("last_reset_month") private var lastResetMonth: String = ""
    @AppStorage("subscription_tier") private var storedTier: String = "ad_supported"
    @AppStorage("subscription_expiry") private var subscriptionExpiryTimestamp: Double = 0

    private init() {
        loadSubscriptionState()
        resetUsageIfNewMonth()
    }

    private func loadSubscriptionState() {
        // Load current tier
        currentTier = SubscriptionTier(rawValue: storedTier) ?? .adSupported

        // Load usage
        usageThisMonth = monthlyUsageCount

        // Load subscription expiry
        if subscriptionExpiryTimestamp > 0 {
            subscriptionExpiryDate = Date(timeIntervalSince1970: subscriptionExpiryTimestamp)
            isSubscriptionActive = Date() < subscriptionExpiryDate!
        }

        // Check if subscription expired
        if let expiryDate = subscriptionExpiryDate, Date() > expiryDate {
            currentTier = .adSupported // Downgrade to ad-supported
            isSubscriptionActive = false
            saveSubscriptionState()
        }
    }

    private func saveSubscriptionState() {
        storedTier = currentTier.rawValue
        monthlyUsageCount = usageThisMonth

        if let expiryDate = subscriptionExpiryDate {
            subscriptionExpiryTimestamp = expiryDate.timeIntervalSince1970
        }
    }

    private func resetUsageIfNewMonth() {
        let currentMonth = DateFormatter.monthYear.string(from: Date())

        if lastResetMonth != currentMonth {
            usageThisMonth = 0
            monthlyUsageCount = 0
            lastResetMonth = currentMonth
            print("🔄 Monthly usage reset for \(currentMonth)")
        }
    }

    // MARK: - Usage Management
    func incrementUsage() {
        usageThisMonth += 1
        saveSubscriptionState()
        print("📊 Usage incremented: \(usageThisMonth)/\(currentTier.monthlyLimit)")
    }

    func canPerformIdentification() -> Bool {
        switch currentTier {
        case .free:
            return usageThisMonth < currentTier.monthlyLimit
        case .adSupported:
            return usageThisMonth < currentTier.monthlyLimit
        case .premium:
            return true // Unlimited
        }
    }

    func remainingIdentifications() -> Int {
        switch currentTier {
        case .premium:
            return Int.max
        default:
            return max(0, currentTier.monthlyLimit - usageThisMonth)
        }
    }

    // MARK: - Subscription Management
    func upgradeTo(tier: SubscriptionTier) {
        currentTier = tier

        switch tier {
        case .premium:
            // Set expiry to 1 month from now
            subscriptionExpiryDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
            isSubscriptionActive = true
        case .adSupported:
            subscriptionExpiryDate = nil
            isSubscriptionActive = false
        case .free:
            subscriptionExpiryDate = nil
            isSubscriptionActive = false
        }

        saveSubscriptionState()
        print("🎯 Upgraded to \(tier.displayName)")
    }

    func cancelSubscription() {
        if currentTier == .premium {
            // Grace period - keep premium until expiry
            print("⏰ Premium subscription will expire on \(subscriptionExpiryDate?.formatted() ?? "unknown")")
        } else {
            currentTier = .adSupported
            subscriptionExpiryDate = nil
            isSubscriptionActive = false
            saveSubscriptionState()
        }
    }

    // MARK: - Subscription Status
    func getSubscriptionStatus() -> String {
        switch currentTier {
        case .free:
            return "Free Plan - \(remainingIdentifications()) identifications remaining"
        case .adSupported:
            return "Ad-Supported - \(remainingIdentifications()) identifications remaining"
        case .premium:
            if let expiryDate = subscriptionExpiryDate {
                return "Premium - Expires \(DateFormatter.shortDate.string(from: expiryDate))"
            } else {
                return "Premium - Unlimited identifications"
            }
        }
    }

    func shouldShowUpgradePrompt() -> Bool {
        switch currentTier {
        case .free:
            return usageThisMonth >= currentTier.monthlyLimit
        case .adSupported:
            return usageThisMonth >= currentTier.monthlyLimit - 5 // Show when 5 left
        case .premium:
            return false
        }
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}
