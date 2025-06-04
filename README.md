# ShootVeil - Intelligent Object Identification iOS App

An advanced iOS app built with SwiftUI that uses AI and spatial metadata to identify buildings, landmarks, and aircraft from camera photos using GPS, compass, and directional data.

## 🎯 Features

### Core Functionality
- **📸 Smart Camera Capture** - High-resolution photo capture with zoom controls
- **🏢 Building & Landmark Identification** - AI-powered identification using Google Vision API
- **✈️ Aircraft Identification** - Real-time aircraft detection using FlightAware API
- **📍 GPS & Spatial Metadata** - Precise location and directional context
- **🧭 Compass Integration** - Heading and orientation tracking
- **📱 Modern SwiftUI Interface** - Native iOS design with haptic feedback

### Advanced Features
- **📊 Capture History** - Persistent storage and management of identifications
- **📤 Content Sharing** - Export results with metadata
- **⚙️ Smart Settings** - API key management and preferences
- **💰 Monetization** - Google AdMob integration with subscription tiers
- **🔄 Usage Tracking** - Monthly limits and subscription management

## 🏗️ Architecture

### Core Services
- **CameraManager** - Camera session management and photo capture
- **LocationManager** - GPS, compass, and spatial data collection
- **IdentificationManager** - AI identification coordination
- **GoogleAPIManager** - Google Vision and Places API integration
- **FlightAwareManager** - Aircraft tracking and identification
- **AdManager** - Google Mobile Ads integration
- **SubscriptionManager** - Usage tracking and subscription handling

### Data Models
- **CaptureMetadata** - Comprehensive spatial and camera metadata
- **Building** - Building/landmark identification results
- **Aircraft** - Aircraft identification and flight data

## 📱 Supported Capture Modes

### 🏢 Landmarks & Buildings
- Architectural identification
- Historical landmarks
- Points of interest
- Google Places integration

### ✈️ Aircraft Detection
- Real-time flight tracking
- Aircraft model identification
- FlightAware integration
- Spatial coordinate processing

### 🚢 Marine Vessels (Coming Soon)
- Ship and boat identification
- Maritime tracking integration

## 🛠️ Technical Requirements

### Development Environment
- **Xcode 15.0+**
- **iOS 16.0+**
- **Swift 5.9+**
- **SwiftUI**

### External Dependencies
- **Google Mobile Ads SDK** - v12.5.0+
- **AVFoundation** - Camera and media capture
- **CoreLocation** - GPS and location services
- **MapKit** - Mapping and coordinate transformations

### API Integrations
- **Google Vision API** - Image analysis and landmark detection
- **Google Places API** - Location enrichment and details
- **Google Geocoding API** - Coordinate to address conversion
- **FlightAware API** - Aircraft identification and tracking

## 🔧 Configuration

### API Keys Required
1. **Google Vision API Key**
2. **Google Places API Key**
3. **FlightAware API Key**
4. **Google AdMob App ID & Ad Unit IDs**

### App Configuration
- Update `Info.plist` with proper permissions
- Configure `ShootVeil.entitlements` for app capabilities
- Set up Google Mobile Ads App ID in `Info.plist`

## 📊 Monetization

### Subscription Tiers
1. **Free Tier** - 5 identifications per month
2. **Ad-Supported** - 30 identifications per month with ads
3. **Premium** - Unlimited identifications ($3.99/month)

### Ad Integration
- **App Open Ads** - On app launch
- **Interstitial Ads** - After identifications
- **Banner Ads** - In settings and non-critical screens
- **Rewarded Ads** - For bonus identifications

## 🚀 Getting Started

### 1. Clone Repository
```bash
git clone https://github.com/mefrati75/shootveil.git
cd shootveil
```

### 2. Configure API Keys
- Add your API keys to the respective service managers
- Update Google AdMob configuration

### 3. Build and Run
- Open `ShootVeil.xcodeproj` in Xcode
- Build and run on iOS device (camera required)

## 📋 Project Structure

```
ShootVeil/
├── ShootVeil/
│   ├── ShootVeilApp.swift          # App entry point
│   ├── ContentView.swift           # Main UI controller
│   ├── Views/                      # SwiftUI views
│   │   ├── WelcomeView.swift
│   │   ├── SplashView.swift
│   │   ├── ResultsView.swift
│   │   ├── HistoryView.swift
│   │   └── SettingsView.swift
│   ├── Services/                   # Core business logic
│   │   ├── CameraManager.swift
│   │   ├── LocationManager.swift
│   │   ├── IdentificationManager.swift
│   │   ├── GoogleAPIManager.swift
│   │   ├── FlightAwareManager.swift
│   │   ├── AdManager.swift
│   │   ├── SubscriptionManager.swift
│   │   ├── ShareManager.swift
│   │   └── LocalDataSource.swift
│   ├── Models/                     # Data structures
│   │   └── CaptureMetadata.swift
│   ├── Assets.xcassets/           # App assets
│   ├── Info.plist                 # App configuration
│   └── ShootVeil.entitlements     # App permissions
```

## 🔐 Privacy & Permissions

### Required Permissions
- **Camera Access** - For photo capture functionality
- **Location Services** - For GPS and spatial identification
- **Network Access** - For API communications

### Privacy Compliance
- Clear privacy usage descriptions
- Secure API key storage
- User control over data sharing
- GDPR/privacy regulation compliance

## 🐛 Known Issues & Solutions

### Camera Session Conflicts
- **Issue**: Google Mobile Ads SDK can conflict with camera access
- **Solution**: Delayed ads initialization after camera setup

### Threading Performance
- **Issue**: AVCaptureSession on main thread warnings
- **Solution**: Background thread camera operations

### API Rate Limiting
- **Issue**: API request limits and quotas
- **Solution**: Intelligent caching and retry logic

## 🚧 Development Status

### ✅ Completed Features
- Core camera and location services
- Google APIs integration
- FlightAware integration
- Basic UI and navigation
- Subscription management
- Google AdMob integration

### 🔄 In Progress
- Enhanced error handling
- Performance optimizations
- Additional identification sources

### 📋 Planned Features
- Marine vessel identification
- Offline identification capabilities
- Social sharing features
- Advanced analytics

## 📝 Version History

### v1.0.0 (Current)
- Initial release
- Core identification features
- Google APIs integration
- AdMob monetization
- Subscription system

## 👨‍💻 Developer

**Maor Efrati** - [@mefrati75](https://github.com/mefrati75)

## 📄 License

This project is proprietary software. All rights reserved.

## 🤝 Support

For support, issues, or feature requests, please contact the development team or create an issue in this repository.

---

**Built with ❤️ using SwiftUI and modern iOS development practices**
