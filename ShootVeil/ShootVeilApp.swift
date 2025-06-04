//
//  ShootVeilApp.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI
import AVFoundation

@main
struct ShootVeilApp: App {
    @StateObject private var adManager = AdManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var appStartupComplete = false

    init() {
        print("🚀 APP INIT STARTED")

        // Check what's using camera resources at startup
        checkSystemResourcesAtStartup()

        print("🚀 APP INIT COMPLETED")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adManager)
                .onAppear {
                    if !appStartupComplete {
                        print("🎬 APP FIRST APPEAR")
                        appStartupComplete = true

                        // TEMPORARILY DISABLE startup camera test to avoid conflicts
                        // checkCameraAvailabilityAtStartup()
                        print("⚠️ STARTUP: Camera test disabled to avoid resource conflicts")
                    }
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

    private func checkSystemResourcesAtStartup() {
        print("🔍 STARTUP: Checking system resources...")

        // System information
        let device = UIDevice.current
        print("🔍 STARTUP: Device: \(device.model) - \(device.systemName) \(device.systemVersion)")
        print("🔍 STARTUP: Device name: \(device.name)")

        // Memory info
        let processInfo = ProcessInfo.processInfo
        print("🔍 STARTUP: Memory: \(processInfo.physicalMemory / 1024 / 1024 / 1024) GB")
        print("🔍 STARTUP: Active processor count: \(processInfo.activeProcessorCount)")

        // Check camera authorization status
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔍 STARTUP: Camera auth status: \(cameraStatus)")

        // Check if any camera devices are available
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        print("🔍 STARTUP: Available cameras: \(cameras.count)")

        // Check for any active capture sessions
        print("🔍 STARTUP: Checking for existing capture sessions...")

        // List camera devices and their states
        for camera in cameras {
            print("🔍 STARTUP: Camera \(camera.localizedName) - connected: \(camera.isConnected), suspended: \(camera.isSuspended)")
        }

        // Check for background app refresh
        if #available(iOS 14.0, *) {
            let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
            print("🔍 STARTUP: Background refresh: \(backgroundRefreshStatus)")
        }

        // Check audio session
        let audioSession = AVAudioSession.sharedInstance()
        print("🔍 STARTUP: Audio session category: \(audioSession.category)")
        print("🔍 STARTUP: Audio session active: \(audioSession.isOtherAudioPlaying)")
    }

    private func checkCameraAvailabilityAtStartup() {
        print("📹 STARTUP: Testing camera availability...")

        DispatchQueue.global(qos: .userInitiated).async {
            // Try to create a minimal session to test camera availability
            let testSession = AVCaptureSession()

            guard let camera = AVCaptureDevice.default(for: .video) else {
                print("❌ STARTUP: No camera device available")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)

                if testSession.canAddInput(input) {
                    testSession.addInput(input)
                    print("✅ STARTUP: Camera input can be added")

                    // Try to start the session briefly
                    testSession.startRunning()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let running = testSession.isRunning
                        let interrupted = testSession.isInterrupted

                        print("📊 STARTUP TEST: running=\(running), interrupted=\(interrupted)")

                        if interrupted {
                            print("💥 STARTUP: Camera already interrupted at app launch!")
                            print("🔍 STARTUP: This suggests system-level interference")
                        } else {
                            print("✅ STARTUP: Camera working at launch")
                        }

                        // CRITICAL: Properly clean up test session to avoid conflicts
                        print("🧹 STARTUP: Cleaning up test session...")
                        testSession.stopRunning()

                        // Remove inputs to fully release camera resource
                        for input in testSession.inputs {
                            testSession.removeInput(input)
                        }

                        print("✅ STARTUP: Test session cleaned up - camera released")
                    }
                } else {
                    print("❌ STARTUP: Cannot add camera input")
                }
            } catch {
                print("❌ STARTUP: Error creating camera input: \(error)")
            }
        }
    }
}
