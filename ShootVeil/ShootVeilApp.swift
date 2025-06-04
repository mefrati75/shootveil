//
//  ShootVeilApp.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI

@main
struct ShootVeilApp: App {
    @StateObject private var adManager = AdManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adManager)
                .onAppear {
                    print("🚀 ShootVeil app launched")
                    // AdManager automatically initializes Google Mobile Ads

                    // Show App Open ad after small delay to ensure proper app launch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if adManager.shouldShowAppOpenAd() {
                            adManager.showAppOpenAd()
                        }
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        print("📱 App became active")
                        // Show App Open ad when app becomes active (returning from background)
                        if oldPhase == .background || oldPhase == .inactive {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if adManager.shouldShowAppOpenAd() {
                                    adManager.showAppOpenAd()
                                }
                            }
                        }
                    case .background:
                        print("📱 App entered background")
                    case .inactive:
                        print("📱 App became inactive")
                    @unknown default:
                        break
                    }
                }
        }
    }
}
