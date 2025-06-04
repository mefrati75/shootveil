# ShootVeil iOS App - Product Requirements Document

## Product Overview

**Product Name:** ShootVeil  
**Platform:** iOS (iPhone)  
**Version:** 1.0  
**Target Release:** [TBD]  
**Geographic Scope:** United States  
**Monetization:** Freemium (first few identifications free, then paid)

### Vision Statement
ShootVeil transforms your iPhone camera into an intelligent identification tool that reveals information about buildings, landmarks, and aircraft through precise aim-and-shoot interaction combined with spatial metadata.

### Product Mission
Enable users to instantly identify and learn about buildings, landmarks, and aircraft in the United States by capturing photos enriched with location, orientation, and directional data for intelligent object recognition.

## Core Value Proposition
- **Instant Identification**: Point, shoot, and immediately know what you're looking at
- **Spatial Intelligence**: Leverages precise angle, distance, and location data
- **Universal Recognition**: Identifies buildings, aircraft, boats, landmarks, and more
- **Augmented Reality Experience**: Overlay digital information on physical world

## Key Features

### 1. Intelligent Camera Capture
- **Photo Capture**: High-quality image capture with metadata embedding
- **Spatial Metadata Collection**:
  - GPS coordinates (latitude/longitude)
  - Device orientation (pitch, roll, yaw)
  - Compass azimuth (0-360°)
  - Altitude/elevation
  - Timestamp
  - Camera parameters (focal length, field of view)

### 2. Object Recognition & Identification
- **Visual Recognition**: AI-powered object identification from photos
- **Contextual Analysis**: Combines visual data with spatial metadata
- **Category Support**: Buildings, landmarks, and aircraft (boats in future versions)
- **Confidence Scoring**: Reliability indicator for identifications
- **Offline Recognition**: Core functionality works without internet connection

### 3. Information Display
- **Object Details**: Name, description, specifications, historical data
- **Interactive Interface**: Tap to explore detailed information
- **Related Content**: Links to maps, websites, additional resources
- **Distance Calculation**: Estimated distance to identified objects

### 4. Data Integration
- **Building Databases**: US architectural and landmark databases
- **Aviation Data**: Flight tracking integration (FlightAware, ADS-B) for US airspace
- **Geographic Data**: US topographic and infrastructure databases
- **Offline Data**: Pre-loaded databases for core functionality without internet

## Monetization Strategy
- **Freemium Model**: First 5-10 identifications free per month
- **Premium Subscription**: Unlimited identifications, advanced features
- **One-time Purchase Option**: Alternative to subscription for power users

## User Stories

### Primary User Flows
1. **Quick Identification**: User opens app → aims at object → taps capture → receives instant identification
2. **Detailed Exploration**: User captures → reviews results → taps for more info → explores related content
3. **Location Context**: User captures → views distance/direction → accesses maps/navigation

## Technical Architecture Strategy

### Recognition Approach
**Aircraft Identification:**
- Real-time flight tracking via FlightAware API
- Calculate direction line using GPS + compass bearing
- Match direction with live flight data along that vector
- No user interaction needed - automatic identification

**Building/Landmark Identification:**
- User taps on building in photo to mark target
- Convert tap coordinates to real-world bearing/direction
- Query buildings along that specific direction line
- Line-of-sight filtering removes buildings blocked by others
- Present list of candidate buildings for user selection

### Core Calculation Logic
**Aircraft (Automatic):**
1. GPS position + compass bearing = direction vector
2. FlightAware API query along direction vector
3. Return closest aircraft match

**Buildings (Interactive):**
1. User captures photo
2. User taps on desired building in photo
3. Convert tap position to compass bearing
4. Query building database along that bearing
5. Filter for line-of-sight visibility
6. Present options to user for final selection

## Technical Implementation Details

### Core iOS Architecture

**Required iOS Frameworks:**
- **AVFoundation**: Camera capture and photo processing
- **Core Location**: GPS coordinates, altitude, heading
- **Core Motion**: Device orientation (pitch, roll, yaw), magnetometer
- **MapKit**: Coordinate conversions and bearing calculations
- **URLSession**: API communications
- **Core Data**: Local storage for offline building data

**Device Requirements:**
- iPhone 8 or newer (for camera quality and sensor accuracy)
- iOS 15.0+ (for latest Core Location features)
- Camera, GPS, magnetometer, accelerometer required
- Internet connection for initial data sync and aircraft tracking

### Data Capture Specifications

**Photo Metadata Collection:**
```swift
struct CaptureMetadata {
    let timestamp: Date
    let gpsCoordinate: CLLocationCoordinate2D
    let altitude: Double // meters above sea level
    let heading: Double // compass bearing (0-360°)
    let pitch: Double // device tilt angle
    let roll: Double // device rotation angle
    let cameraFocalLength: Float
    let imageResolution: CGSize
}
```

**Bearing Calculation from Photo Tap:**
```swift
func calculateBearingFromTap(tapPoint: CGPoint, imageSize: CGSize, 
                           deviceHeading: Double, cameraFOV: Double) -> Double {
    let normalizedX = (tapPoint.x / imageSize.width) - 0.5 // -0.5 to 0.5
    let bearingOffset = normalizedX * cameraFOV
    return deviceHeading + bearingOffset
}
```

### Aircraft Identification System

**FlightAware API Integration:**
- **Endpoint**: `/flights/search/advanced-position`
- **Query Parameters**: 
  - Bounding box around direction vector
  - Current timestamp
  - Aircraft type filters
- **Response Processing**: Match aircraft within 5° bearing tolerance

**Algorithm Flow:**
1. Calculate direction vector from GPS + compass bearing
2. Create search area: ±2.5° from center bearing, 50km radius
3. Query FlightAware for aircraft in search area
4. Return closest aircraft to center bearing
5. Display: Aircraft type, flight number, origin/destination, altitude

### Building Identification System

**Tap-to-Coordinate Conversion:**
```swift
func convertTapToBearing(photo: UIImage, tapPoint: CGPoint, 
                        deviceHeading: Double) -> Double {
    let horizontalFOV = calculateCameraFOV() // ~68° for iPhone camera
    let centerOffset = (tapPoint.x / photo.size.width) - 0.5
    let bearingOffset = centerOffset * horizontalFOV
    return deviceHeading + bearingOffset
}
```

**Building Database Query:**
1. Calculate target bearing from photo tap
2. Query building database within ±1° bearing tolerance
3. Sort results by distance from device
4. Apply line-of-sight filtering (remove buildings behind others)
5. Return top 3-5 candidates

**Building Data Structure:**
```swift
struct Building {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let height: Double // meters
    let type: BuildingType // landmark, office, residential, etc.
    let description: String
    let wikipediaURL: String?
    let constructionYear: Int?
}
```

### API Integration Strategy

**Primary APIs Required:**
1. **FlightAware API**
   - Real-time aircraft positions
   - Flight details and tracking

2. **Google Gemini AI**
   - Building/landmark recognition from photos
   - Visual confirmation of identified objects

3. **Google Maps Geocoding API**
   - Reverse geocoding for building identification
   - Address and place name resolution

**API Rate Limiting Strategy:**
- Implement local caching to reduce API calls
- Queue non-urgent requests for batch processing
- Graceful degradation when rate limits are reached

### Offline Functionality

**Pre-loaded Databases:**
- **Major US Landmarks**: ~2,000 significant buildings/monuments
- **Airport Data**: All US airports for aviation context
- **City Building Data**: Basic building footprints for major cities
- **Total Storage**: ~50-100MB for core offline data

**Offline Capability Matrix:**
| Feature | Online | Offline |
|---------|--------|---------|
| Aircraft ID | Full details | Basic type only |
| Landmark ID | Full info + photos | Name + basic info |
| Building ID | Real-time data | Cached data only |
| Photo capture | Full metadata | Full metadata |

### Data Synchronization

**Update Strategy:**
- Daily sync for flight route data
- Weekly sync for building database updates
- Real-time sync for aircraft positions (when online)
- User-initiated sync for major database updates

**Caching Logic:**
```swift
struct CacheStrategy {
    let aircraftCacheDuration: TimeInterval = 60 // 1 minute
    let buildingCacheDuration: TimeInterval = 86400 // 24 hours
    let landmarkCacheDuration: TimeInterval = 604800 // 7 days
}
```

### Privacy & Security

**Data Collection:**
- Photo metadata stored locally only
- GPS coordinates encrypted in transit
- No photos uploaded to servers without explicit user consent
- User location data anonymized for API queries

**API Security:**
- API keys stored in iOS Keychain
- Certificate pinning for all network requests
- Request signing for sensitive APIs
- Rate limiting to prevent abuse

### Performance Optimization

**Target Performance Metrics:**
- Photo capture to initial results: < 3 seconds
- Aircraft identification: < 2 seconds
- Building identification: < 4 seconds (including user selection)
- App startup time: < 2 seconds
- Battery usage: < 5% per hour of active use

**Optimization Strategies:**
- Background processing for API calls
- Image compression before analysis
- Lazy loading of building databases
- Efficient coordinate calculations using native iOS frameworks

### Performance Requirements
- **Capture Speed**: < 2 seconds from tap to initial results
- **Recognition Accuracy**: Target 85%+ for common objects
- **Battery Usage**: Optimized for extended outdoor use
- **Offline Capability**: [TBD based on data strategy]

## Success Metrics
- **User Engagement**: Daily active users, session duration
- **Recognition Accuracy**: Successful identification rate
- **User Satisfaction**: App store ratings, user feedback
- **Technical Performance**: Capture speed, crash rate, battery impact

---

**Questions for Further Definition

**Priority & Scope:**
1. ✅ Primary target for V1: Buildings, landmarks, and aircraft
2. ✅ Geographic region: United States  
3. ✅ Monetization: Freemium model with paid premium features

**Technical Architecture:**
4. ✅ User interaction: Capture-then-process with tap-to-identify for buildings
5. ✅ Connectivity: Hybrid online/offline functionality
6. ✅ Recognition approach: API integration with geometric calculations

**User Experience:**
7. ✅ App style: Camera-focused application
8. ✅ Data persistence: Local storage only for privacy
9. ✅ User accounts: Local usage without mandatory accounts

**Data & Integration:**
10. ✅ API strategy: FlightAware + Google Gemini + Google Geocoding
11. ✅ User feedback: Simple selection from candidate results
12. ✅ Data freshness: Real-time for aircraft, cached for buildings/landmarks