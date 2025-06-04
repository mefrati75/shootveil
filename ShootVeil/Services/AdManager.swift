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

    private var appOpenAd: AppOpenAd?
    private var interstitialAd: InterstitialAd?
    private var rewardedAd: RewardedAd?

    override init() {
        super.init()
        print("📱 AdManager: Initializing Google Mobile Ads")
        initializeAdMob()
    }

    private func initializeAdMob() {
        MobileAds.shared.start { [weak self] status in
            DispatchQueue.main.async {
                self?.isAdMobInitialized = true
                print("✅ AdMob initialization completed")
                self?.loadAppOpenAd()
            }
        }
    }

    func loadAppOpenAd() {
        guard isAdMobInitialized else { return }

        let adUnitID = "ca-app-pub-3940256099942544/5662855259" // Test Ad Unit ID

        let request = Request()
        AppOpenAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ App Open Ad failed to load: \(error.localizedDescription)")
                    self?.adError = error.localizedDescription
                    return
                }

                self?.appOpenAd = ad
                self?.isAdLoaded = true
                print("✅ App Open Ad loaded successfully")
            }
        }
    }

    func showAppOpenAd() {
        guard let appOpenAd = appOpenAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No App Open Ad available or no root view controller")
            return
        }

        appOpenAd.present(from: rootViewController)
        self.appOpenAd = nil
        self.isAdLoaded = false

        // Load next ad
        loadAppOpenAd()
    }

    func loadInterstitialAd() {
        guard isAdMobInitialized else { return }

        let adUnitID = "ca-app-pub-3940256099942544/1033173712" // Test Ad Unit ID

        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Interstitial Ad failed to load: \(error.localizedDescription)")
                    self?.adError = error.localizedDescription
                    return
                }

                self?.interstitialAd = ad
                print("✅ Interstitial Ad loaded successfully")
            }
        }
    }

    func showInterstitialAd() {
        guard let interstitialAd = interstitialAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No Interstitial Ad available or no root view controller")
            return
        }

        interstitialAd.present(from: rootViewController)
        self.interstitialAd = nil

        // Load next ad
        loadInterstitialAd()
    }

    func loadRewardedAd() {
        guard isAdMobInitialized else { return }

        let adUnitID = "ca-app-pub-3940256099942544/1712485313" // Test Ad Unit ID

        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Rewarded Ad failed to load: \(error.localizedDescription)")
                    self?.adError = error.localizedDescription
                    return
                }

                self?.rewardedAd = ad
                print("✅ Rewarded Ad loaded successfully")
            }
        }
    }

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No Rewarded Ad available or no root view controller")
            completion(false)
            return
        }

        rewardedAd.present(from: rootViewController, userDidEarnRewardHandler: {
            let reward = rewardedAd.adReward
            print("✅ User earned reward: \(reward.amount) \(reward.type)")
            completion(true)
        })

        self.rewardedAd = nil

        // Load next ad
        loadRewardedAd()
    }

    func loadBannerAd() {
        print("📱 Banner ad loading requested")
    }

    func shouldShowAdAfterIdentification(count: Int) -> Bool {
        // Show ad every 3 identifications
        return count > 0 && count % 3 == 0
    }

    func offerRewardedAdForExtraIdentification(completion: @escaping (Bool) -> Void) {
        // Show rewarded ad for bonus identification
        showRewardedAd(completion: completion)
    }

    func shouldShowAppOpenAd() -> Bool {
        return isAdLoaded && appOpenAd != nil
    }

    func startAdsAfterCameraSetup() {
        print("📱 Starting ads after camera setup")
        // Load initial ads
        loadInterstitialAd()
        loadRewardedAd()
    }
}

// MARK: - SwiftUI Banner Ad View
struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716" // Test Ad Unit ID

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }

        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // No updates needed
    }
}
