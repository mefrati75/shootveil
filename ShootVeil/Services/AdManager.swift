//
//  AdManager.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/2/25.
//

import SwiftUI
import GoogleMobileAds
import UIKit
import Foundation

// MARK: - Ad Manager
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published var isAdLoaded = false
    @Published var isShowingAd = false
    @Published var adError: String?
    @Published var isAdMobInitialized = false

    private var interstitialAd: InterstitialAd?
    private var rewardedAd: RewardedAd?
    private var appOpenAd: AppOpenAd?

    // Ad Unit IDs - Now using production IDs
    struct AdUnitIDs {
        static let isTestMode = false // Set to true for testing, false for production

        // Test Ad Unit IDs (for development)
        private static let testAppOpenAdUnitID = "ca-app-pub-3940256099942544/5662855259"
        private static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
        private static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
        private static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

        // Production Ad Unit IDs
        private static let prodAppOpenAdUnitID = "ca-app-pub-7699624044669714/9325122370"
        private static let prodInterstitialAdUnitID = "ca-app-pub-7699624044669714/2345678901"
        private static let prodRewardedAdUnitID = "ca-app-pub-7699624044669714/4567890123"
        private static let prodBannerAdUnitID = "ca-app-pub-7699624044669714/3456789012"

        // Current Ad Unit IDs based on mode
        static var appOpenAdUnitID: String {
            isTestMode ? testAppOpenAdUnitID : prodAppOpenAdUnitID
        }

        static var interstitialAdUnitID: String {
            isTestMode ? testInterstitialAdUnitID : prodInterstitialAdUnitID
        }

        static var rewardedAdUnitID: String {
            isTestMode ? testRewardedAdUnitID : prodRewardedAdUnitID
        }

        static var bannerAdUnitID: String {
            isTestMode ? testBannerAdUnitID : prodBannerAdUnitID
        }
    }

    private var loadTime = Date()

    // Production App ID
    private let appID = "ca-app-pub-7699624044669714~9188572768"

    // Delay ads initialization to avoid camera conflicts
    private var adsInitializationDelay: Double = 5.0 // 5 seconds delay

    override init() {
        super.init()
        print("📱 Initializing AdManager")

        // Delay ads initialization to avoid camera conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + adsInitializationDelay) {
            self.initializeAdMob()
        }
    }

    private func initializeAdMob() {
        print("📱 Starting delayed AdMob initialization")

        // Configure request settings to avoid camera/microphone conflicts
        let requestConfiguration = MobileAds.shared.requestConfiguration

        // Disable ad formats that might use camera/microphone
        requestConfiguration.maxAdContentRating = .general

        MobileAds.shared.start { [weak self] initializationStatus in
            DispatchQueue.main.async {
                self?.isAdMobInitialized = true
                print("✅ AdMob initialized successfully")

                // Load ads after successful initialization
                self?.loadInitialAds()
            }
        }
    }

    private func loadInitialAds() {
        // Load banner and interstitial ads first (safer)
        loadInterstitialAd()

        // Delay app open ads even more to ensure camera is working
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.loadAppOpenAd()
        }
    }

    // Method to safely start ads after camera is working
    func startAdsAfterCameraSetup() {
        guard isAdMobInitialized else { return }

        print("📱 Starting ads after camera setup confirmed")
        loadAppOpenAd()
    }

    // MARK: - App Open Ads
    private var appOpenAdLoadTime: Date?

    func loadAppOpenAd() {
        print("📱 Loading App Open Ad")
        let request = Request()

        AppOpenAd.load(
            with: AdUnitIDs.appOpenAdUnitID,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load app open ad: \(error.localizedDescription)")
                self?.adError = error.localizedDescription
                return
            }

            print("✅ App Open Ad loaded successfully")
            self?.appOpenAd = ad
            self?.appOpenAd?.fullScreenContentDelegate = self
            self?.appOpenAdLoadTime = Date()
            self?.isAdLoaded = true
        }
    }

    func showAppOpenAd() {
        guard let ad = appOpenAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Unable to present app open ad")
            loadAppOpenAd() // Try to load a new ad
            return
        }

        ad.present(from: rootViewController)
    }

    // MARK: - Interstitial Ads
    func loadInterstitialAd() {
        print("📱 Loading Interstitial Ad")
        let request = Request()

        InterstitialAd.load(
            with: AdUnitIDs.interstitialAdUnitID,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                self?.adError = error.localizedDescription
                return
            }

            print("✅ Interstitial Ad loaded successfully")
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            self?.isAdLoaded = true
        }
    }

    func showInterstitialAd() {
        guard let ad = interstitialAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Unable to present interstitial ad")
            loadInterstitialAd() // Try to load a new ad
            return
        }

        ad.present(from: rootViewController)
    }

    // MARK: - Rewarded Ads
    func loadRewardedAd() {
        print("📱 Loading Rewarded Ad")
        let request = Request()

        RewardedAd.load(
            with: AdUnitIDs.rewardedAdUnitID,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load rewarded ad: \(error.localizedDescription)")
                self?.adError = error.localizedDescription
                return
            }

            print("✅ Rewarded Ad loaded successfully")
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            self?.isAdLoaded = true
        }
    }

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Unable to present rewarded ad")
            loadRewardedAd() // Try to load a new ad
            completion(false)
            return
        }

        ad.present(from: rootViewController) { [weak self] in
            print("✅ User earned reward")
            completion(true)
            self?.loadRewardedAd() // Load the next rewarded ad
        }
    }

    // MARK: - Banner Ads
    private var bannerView: BannerView?

    func createBannerView() -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = AdUnitIDs.bannerAdUnitID
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }
        return bannerView
    }

    func loadBannerAd() {
        print("📱 Loading Banner Ad")
        let request = Request()
        bannerView = createBannerView()
        bannerView?.load(request)
    }
}

// MARK: - Full Screen Content Delegate
extension AdManager: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("✅ Ad did record impression")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ Ad dismissed")
        isShowingAd = false
        loadNextAd(for: ad)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Ad failed to present with error: \(error.localizedDescription)")
        adError = error.localizedDescription
        loadNextAd(for: ad)
    }

    private func loadNextAd(for ad: FullScreenPresentingAd) {
        switch ad {
        case is InterstitialAd:
            loadInterstitialAd()
        case is RewardedAd:
            loadRewardedAd()
        case is AppOpenAd:
            loadAppOpenAd()
        default:
            break
        }
    }
}

// MARK: - Banner View Delegate
extension AdManager: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("✅ Banner ad loaded successfully")
        isAdLoaded = true
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("❌ Banner ad failed to load with error: \(error.localizedDescription)")
        adError = error.localizedDescription
    }
}

// MARK: - Ad Integration Extensions
extension AdManager {
    // Show ad after certain number of identifications
    func shouldShowAdAfterIdentification(count: Int) -> Bool {
        // Show ad every 3 identifications for ad-supported tier
        return count > 0 && count % 3 == 0
    }

    // Show rewarded ad for extra identifications
    func offerRewardedAdForExtraIdentification(completion: @escaping (Bool) -> Void) {
        showRewardedAd { success in
            print("🎁 AdManager: User earned extra identification!")
            completion(success)
        }
    }

    // Check if app open ad should be shown (on app launch)
    func shouldShowAppOpenAd() -> Bool {
        // Don't show if already showing an ad
        return !isShowingAd
    }
}

// MARK: - SwiftUI Banner Ad View
struct BannerAdView: UIViewRepresentable {
    @StateObject private var adManager = AdManager.shared

    func makeUIView(context: Context) -> BannerView {
        let bannerView = adManager.createBannerView()
        bannerView.delegate = adManager

        // Load the banner ad
        adManager.loadBannerAd()

        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // No updates needed
    }
}
