import UIKit
import AVFoundation
import CoreLocation
import CoreMotion
import SwiftUI

// MARK: - Data Models

struct CaptureMetadata {
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let altitude: Double
    let heading: Double
    let pitch: Double
    let roll: Double
    let yaw: Double
    let focalLength: Float
    let imageSize: CGSize
    let zoom: CGFloat
}

struct ObjectMarking {
    let tapPoint: CGPoint
    let objectHeight: CGFloat
    let objectWidth: CGFloat
}

struct IdentificationResult {
    let name: String
    let description: String
    let distance: Double
    let bearing: String
    let coordinates: CLLocationCoordinate2D
    let confidence: Double
    let category: String // "building", "aircraft", "landmark"
    let additionalInfo: [String: Any]
}

// MARK: - Main View Controller

class CameraViewController: UIViewController {
    
    // MARK: - Properties
    private var captureSession: AVCaptureSession!
    private var stillImageOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var locationManager: CLLocationManager!
    private var motionManager: CMMotionManager!
    
    private var currentLocation: CLLocationCoordinate2D?
    private var currentHeading: Double = 0
    private var currentAttitude: CMAttitude?
    
    // UI Elements
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var freeCountLabel: UILabel!
    @IBOutlet weak var crosshairView: UIImageView!
    
    // User data
    private var freeIdentificationsLeft = 5
    private var isPremiumUser = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        setupLocationManager()
        setupMotionManager()
        checkPermissions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCapturing()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopCapturing()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        title = "ShootVeil"
        view.backgroundColor = .black
        
        // Style capture button
        captureButton.layer.cornerRadius = 35
        captureButton.backgroundColor = .white
        captureButton.setTitle("CAPTURE", for: .normal)
        captureButton.setTitleColor(.black, for: .normal)
        captureButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        
        // Add haptic feedback
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        
        // Setup crosshair
        crosshairView.image = UIImage(systemName: "plus.circle")
        crosshairView.tintColor = .white.withAlphaComponent(0.5)
        
        updateFreeCountLabel()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showAlert(title: "Camera Error", message: "Unable to access camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        } catch {
            showAlert(title: "Camera Error", message: "Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    private func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.videoPreviewLayer.frame = self?.previewView.bounds ?? CGRect.zero
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupMotionManager() {
        motionManager = CMMotionManager()
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let motion = motion else { return }
                self?.currentAttitude = motion.attitude
            }
        }
    }
    
    // MARK: - Permissions
    
    private func checkPermissions() {
        checkCameraPermission()
        checkLocationPermission()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if !granted {
                    DispatchQueue.main.async {
                        self?.showPermissionAlert(for: "Camera")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert(for: "Camera")
        @unknown default:
            break
        }
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showPermissionAlert(for: "Location")
        @unknown default:
            break
        }
    }
    
    private func showPermissionAlert(for permission: String) {
        let alert = UIAlertController(
            title: "\(permission) Access Needed",
            message: "ShootVeil needs \(permission.lowercased()) access to identify landmarks. Please enable it in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Camera Control
    
    private func startCapturing() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    private func stopCapturing() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - Capture Action
    
    @objc private func captureButtonTapped() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Check if user can capture
        if !canCapture() {
            showUpgradePrompt()
            return
        }
        
        // Check if location is available
        guard let location = currentLocation else {
            showAlert(title: "Location Required", message: "Please wait for GPS to lock your location.")
            return
        }
        
        // Capture photo
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        stillImageOutput.capturePhoto(with: settings, delegate: self)
        
        // Update UI
        captureButton.isEnabled = false
        statusLabel.text = "Capturing..."
    }
    
    private func canCapture() -> Bool {
        return isPremiumUser || freeIdentificationsLeft > 0
    }
    
    private func updateFreeCountLabel() {
        if isPremiumUser {
            freeCountLabel.text = "Premium ∞"
            freeCountLabel.textColor = .systemGold
        } else {
            freeCountLabel.text = "\(freeIdentificationsLeft) free shots left"
            freeCountLabel.textColor = freeIdentificationsLeft > 0 ? .white : .systemRed
        }
    }
    
    // MARK: - Navigation
    
    private func showObjectSelectionViewController(with image: UIImage, metadata: CaptureMetadata) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let objectSelectionVC = storyboard.instantiateViewController(withIdentifier: "ObjectSelectionViewController") as? ObjectSelectionViewController else {
            return
        }
        
        objectSelectionVC.capturedImage = image
        objectSelectionVC.metadata = metadata
        objectSelectionVC.delegate = self
        
        navigationController?.pushViewController(objectSelectionVC, animated: true)
    }
    
    private func showUpgradePrompt() {
        let alert = UIAlertController(
            title: "🎯 You're exploring like a pro!",
            message: "You've used all your free identifications this month.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "📺 Watch Video (+25 IDs)", style: .default) { [weak self] _ in
            self?.showRewardedVideo()
        })
        
        alert.addAction(UIAlertAction(title: "💎 Go Premium ($4.99)", style: .default) { [weak self] _ in
            self?.showPremiumUpgrade()
        })
        
        alert.addAction(UIAlertAction(title: "Maybe Later", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showRewardedVideo() {
        // TODO: Integrate with video ad SDK (Unity Ads, AdMob, etc.)
        // For now, simulate watching video
        
        let alert = UIAlertController(
            title: "Watch 30-second video?",
            message: "Get 25 more identifications by watching a short video.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Watch Video", style: .default) { [weak self] _ in
            // Simulate video completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.freeIdentificationsLeft += 25
                self?.updateFreeCountLabel()
                self?.showAlert(title: "🎉 Bonus Unlocked!", message: "You've earned 25 more identifications!")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showPremiumUpgrade() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let premiumVC = storyboard.instantiateViewController(withIdentifier: "PremiumViewController") as? PremiumViewController else {
            return
        }
        
        premiumVC.delegate = self
        present(premiumVC, animated: true)
    }
    
    // MARK: - Utility Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData),
              let location = currentLocation,
              let attitude = currentAttitude else {
            
            DispatchQueue.main.async { [weak self] in
                self?.captureButton.isEnabled = true
                self?.statusLabel.text = "Ready"
                self?.showAlert(title: "Capture Failed", message: "Unable to capture photo or sensor data")
            }
            return
        }
        
        // Create metadata
        let metadata = CaptureMetadata(
            timestamp: Date(),
            location: location,
            altitude: locationManager.location?.altitude ?? 0,
            heading: currentHeading,
            pitch: attitude.pitch,
            roll: attitude.roll,
            yaw: attitude.yaw,
            focalLength: getCurrentFocalLength(),
            imageSize: image.size,
            zoom: getCurrentZoom()
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.captureButton.isEnabled = true
            self?.statusLabel.text = "Ready"
            self?.showObjectSelectionViewController(with: image, metadata: metadata)
        }
    }
    
    private func getCurrentFocalLength() -> Float {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return 4.25 // iPhone default approximation
        }
        
        let format = device.activeFormat
        let fov = format.videoFieldOfView
        let sensorWidth: Float = 4.8 // iPhone sensor width in mm
        let fovRadians = fov * .pi / 180
        return sensorWidth / (2 * tan(fovRadians / 2))
    }
    
    private func getCurrentZoom() -> CGFloat {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return 1.0
        }
        return device.videoZoomFactor
    }
}

// MARK: - CLLocationManagerDelegate

extension CameraViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "📍 GPS Ready  🧭 Compass Ready"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading.trueHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionAlert(for: "Location")
            }
        default:
            break
        }
    }
}

// MARK: - Object Selection View Controller

class ObjectSelectionViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    var capturedImage: UIImage!
    var metadata: CaptureMetadata!
    weak var delegate: ObjectSelectionDelegate?
    
    private var isProcessing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        imageView.image = capturedImage
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        instructionLabel.text = "👆 Tap on what you want to identify in the photo"
        instructionLabel.textAlignment = .center
        
        progressView.isHidden = true
        statusLabel.isHidden = true
        
        backButton.setTitle("← Back", for: .normal)
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
        imageView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        guard !isProcessing else { return }
        
        let tapPoint = gesture.location(in: imageView)
        
        // Add visual feedback
        addTapIndicator(at: tapPoint)
        
        // Start processing
        startIdentification(at: tapPoint)
    }
    
    private func addTapIndicator(at point: CGPoint) {
        let indicator = UIView(frame: CGRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30))
        indicator.layer.cornerRadius = 15
        indicator.layer.borderWidth = 2
        indicator.layer.borderColor = UIColor.systemRed.cgColor
        indicator.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
        
        imageView.addSubview(indicator)
        
        // Animate
        indicator.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.3) {
            indicator.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }
    }
    
    private func startIdentification(at tapPoint: CGPoint) {
        isProcessing = true
        
        // Update UI
        instructionLabel.isHidden = true
        progressView.isHidden = false
        statusLabel.isHidden = false
        
        // Simulate processing steps
        animateProgress()
        
        // Create object marking
        let objectMarking = ObjectMarking(
            tapPoint: tapPoint,
            objectHeight: 150, // This would be calculated from user selection in real app
            objectWidth: 80
        )
        
        // Process identification
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processIdentification(objectMarking: objectMarking)
        }
    }
    
    private func animateProgress() {
        let steps = [
            (0.3, "🔍 Calculating distance..."),
            (0.6, "📍 Finding location..."),
            (0.9, "🔎 Identifying landmark...")
        ]
        
        var currentStep = 0
        
        func animateNextStep() {
            guard currentStep < steps.count else {
                return
            }
            
            let (progress, message) = steps[currentStep]
            
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.5) {
                    self?.progressView.setProgress(Float(progress), animated: true)
                }
                self?.statusLabel.text = message
            }
            
            currentStep += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                animateNextStep()
            }
        }
        
        animateNextStep()
    }
    
    private func processIdentification(objectMarking: ObjectMarking) {
        // Use the calculation engine
        let result = ShootVeilCalculations.identifyTarget(
            metadata: metadata,
            objectMarking: objectMarking,
            knownObjects: getLandmarkDatabase()
        )
        
        // Simulate API calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showResults(result: result)
        }
    }
    
    private func getLandmarkDatabase() -> [String: (height: Double, coordinates: CLLocationCoordinate2D)] {
        return [
            "Statue of Liberty": (height: 93.0, coordinates: CLLocationCoordinate2D(latitude: 40.6892, longitude: -74.0445)),
            "Empire State Building": (height: 443.0, coordinates: CLLocationCoordinate2D(latitude: 40.7484, longitude: -73.9857)),
            "Brooklyn Bridge": (height: 84.0, coordinates: CLLocationCoordinate2D(latitude: 40.7061, longitude: -73.9969))
        ]
    }
    
    private func showResults(result: (targetLocation: CLLocationCoordinate2D, estimatedDistance: Double, confidence: Double)) {
        // Create mock result for demo
        let identificationResult = IdentificationResult(
            name: "Statue of Liberty",
            description: "Built in 1886, this copper statue was a gift from France to celebrate America's centennial and the abolition of slavery.",
            distance: result.estimatedDistance,
            bearing: "Southwest",
            coordinates: result.targetLocation,
            confidence: result.confidence,
            category: "landmark",
            additionalInfo: [
                "height": "93 meters",
                "opened": "1886",
                "visitors_per_year": "4.24 million",
                "architect": "Frédéric Auguste Bartholdi"
            ]
        )
        
        // Navigate to results
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let resultsVC = storyboard.instantiateViewController(withIdentifier: "ResultsViewController") as? ResultsViewController else {
            return
        }
        
        resultsVC.result = identificationResult
        resultsVC.originalImage = capturedImage
        
        navigationController?.pushViewController(resultsVC, animated: true)
        
        // Notify delegate
        delegate?.didCompleteIdentification()
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Results View Controller

class ResultsViewController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var directionLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var actionButtonsStackView: UIStackView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var moreInfoButton: UIButton!
    
    var result: IdentificationResult!
    var originalImage: UIImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayResult()
        addCelebration()
    }
    
    private func setupUI() {
        title = "Discovery"
        
        // Style buttons
        shareButton.setTitle("Share 📤", for: .normal)
        saveButton.setTitle("⭐ Save", for: .normal)
        moreInfoButton.setTitle("🎫 Visitor Info", for: .normal)
        
        // Add navigation items
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
    }
    
    private func displayResult() {
        nameLabel.text = "🗽 \(result.name.uppercased())"
        locationLabel.text = "📍 \(formatLocation())"
        distanceLabel.text = "📏 \(formatDistance(result.distance))"
        directionLabel.text = "🧭 \(result.bearing) from your location"
        
        descriptionTextView.text = result.description
        descriptionTextView.isEditable = false
    }
    
    private func formatLocation() -> String {
        // In real app, reverse geocode the coordinates
        return "Liberty Island, NY"
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f meters away", distance)
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }
    
    private func addCelebration() {
        // Add celebration animation
        let celebration = UILabel()
        celebration.text = "🎉"
        celebration.font = UIFont.systemFont(ofSize: 60)
        celebration.frame = CGRect(x: view.center.x - 30, y: 100, width: 60, height: 60)
        view.addSubview(celebration)
        
        celebration.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
            celebration.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0) {
                celebration.alpha = 0
            } completion: { _ in
                celebration.removeFromSuperview()
            }
        }
        
        // Haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        let shareText = "I just discovered the \(result.name) using ShootVeil! 🗽"
        let activityVC = UIActivityViewController(activityItems: [shareText, originalImage as Any], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        // Save to user's discoveries
        sender.setTitle("✅ Saved", for: .normal)
        sender.isEnabled = false
        
        // Animate
        UIView.animate(withDuration: 0.3) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                sender.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }
        }
    }
    
    @IBAction func moreInfoButtonTapped(_ sender: UIButton) {
        // Open visitor information
        if let url = URL(string: "https://www.nps.gov/stli/index.htm") {
            UIApplication.shared.open(url)
        }
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.popToRootViewController(animated: true)
    }
}

// MARK: - Protocols

protocol ObjectSelectionDelegate: AnyObject {
    func didCompleteIdentification()
}

protocol PremiumDelegate: AnyObject {
    func didPurchasePremium()
}

// MARK: - Extensions

extension CameraViewController: ObjectSelectionDelegate {
    func didCompleteIdentification() {
        if !isPremiumUser {
            freeIdentificationsLeft -= 1
            updateFreeCountLabel()
        }
    }
}

extension CameraViewController: PremiumDelegate {
    func didPurchasePremium() {
        isPremiumUser = true
        updateFreeCountLabel()
    }
}

// MARK: - Premium View Controller

class PremiumViewController: UIViewController {
    
    weak var delegate: PremiumDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var featuresStackView: UIStackView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var purchaseButton: UIButton!
    @IBOutlet weak var restoreButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        titleLabel.text = "🚀 Go Premium"
        priceLabel.text = "$4.99/month"
        
        purchaseButton.setTitle("Start Premium", for: .normal)
        purchaseButton.backgroundColor = .systemBlue
        purchaseButton.layer.cornerRadius = 8
        
        // Add premium features
        let features = [
            "✨ Unlimited identifications",
            "📚 Detailed historical information",
            "🎯 Augmented reality overlay",
            "📱 Offline mode for 50 major cities",
            "🎮 Advanced achievement system",
            "📊 Personal discovery stats"
        ]
        
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for feature in features {
            let label = UILabel()
            label.text = feature
            label.font = UIFont.systemFont(ofSize: 16)
            label.textColor = .label
            featuresStackView.addArrangedSubview(label)
        }
    }
    
    @IBAction func purchaseButtonTapped(_ sender: UIButton) {
        // TODO: Integrate with StoreKit for actual purchases
        // For demo, just simulate purchase
        
        purchaseButton.setTitle("Processing...", for: .normal)
        purchaseButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.delegate?.didPurchasePremium()
            self?.dismiss(animated: true)
        }
    }
    
    @IBAction func restoreButtonTapped(_ sender: UIButton) {
        // TODO: Implement restore purchases
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
}