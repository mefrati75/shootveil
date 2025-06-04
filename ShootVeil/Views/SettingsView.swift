//
//  SettingsView.swift
//  ShootVeil
//
//  Created by Maor Efrati on 6/1/25.
//

import SwiftUI
import LocalAuthentication
import CoreLocation
import Photos
import GoogleSignIn
import GoogleSignInSwift

struct SettingsView: View {
    @State private var showingPlanSelection = false
    @State private var showingAccountDetails = false
    @State private var showingAuthentication = false
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var adManager: AdManager

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    Section {
                        SettingRow(
                            icon: "info.circle.fill",
                            title: "About ShootVeil",
                            subtitle: "Intelligent object identification",
                            iconColor: .blue
                        )

                        SettingRow(
                            icon: "envelope.fill",
                            title: "Contact Support",
                            subtitle: "Get help with ShootVeil",
                            iconColor: .green
                        )

                        SettingRow(
                            icon: "star.fill",
                            title: "Rate ShootVeil",
                            subtitle: "Share your experience",
                            iconColor: .orange
                        )
                    } header: {
                        Text("Support")
                    }

                    Section {
                        // Current Plan Row with enhanced ad-supported integration
                        CurrentPlanRow(onUpgradePressed: {
                            showingPlanSelection = true
                        })

                        // Account Details Row
                        Button(action: {
                            if authManager.isAuthenticated {
                                showingAccountDetails = true
                            } else {
                                showingAuthentication = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Account Details")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(authManager.isAuthenticated ? "Manage your account" : "Sign in to sync data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())

                        SettingRow(
                            icon: "chart.bar.fill",
                            title: "Usage Statistics",
                            subtitle: "View your identification usage",
                            iconColor: .orange
                        )
                    } header: {
                        Text("Account")
                    }

                    Section {
                        SettingRow(
                            icon: "lock.fill",
                            title: "Privacy Policy",
                            subtitle: "How we protect your data",
                            iconColor: .gray
                        )

                        SettingRow(
                            icon: "doc.text.fill",
                            title: "Terms of Service",
                            subtitle: "Usage terms and conditions",
                            iconColor: .gray
                        )
                    } header: {
                        Text("Legal")
                    }

                    // App Version
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Show banner ad for Ad-Supported tier users
                if shouldShowBannerAd() {
                    VStack {
                        Divider()
                        BannerAdView()
                            .frame(height: 50)
                            .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingPlanSelection) {
            PlanSelectionView()
                .environmentObject(adManager)
        }
        .sheet(isPresented: $showingAccountDetails) {
            AccountDetailsView()
        }
        .sheet(isPresented: $showingAuthentication) {
            AuthenticationFlow(
                onAuthenticationSuccess: {
                    showingAuthentication = false
                    showingAccountDetails = true
                }
            )
        }
    }

    private func shouldShowBannerAd() -> Bool {
        let currentTier = SubscriptionManager.shared.currentTier
        return currentTier == .adSupported
    }
}

// MARK: - Secure Authentication Manager (Apple Best Practices)
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isAuthenticated = false
    @Published var currentUser: UserAccount?
    @Published var biometricType: LABiometryType = .none

    private let keychain = KeychainManager()
    private let biometricAuth = BiometricAuthManager()

    // Use @AppStorage equivalents for non-sensitive data
    @AppStorage("user_email") private var storedEmail: String = ""
    @AppStorage("user_name") private var storedName: String = ""
    @AppStorage("biometric_enabled") private var biometricEnabled: Bool = false
    @AppStorage("last_login") private var lastLoginTimestamp: Double = 0

    private init() {
        checkBiometricAvailability()
        checkExistingAuthentication()
    }

    private func checkBiometricAvailability() {
        biometricType = biometricAuth.getBiometricType()
    }

    private func checkExistingAuthentication() {
        // Check if user has valid session and credentials
        guard !storedEmail.isEmpty,
              keychain.hasCredentials(for: storedEmail) else {
            return
        }

        // Check session validity (24 hours)
        let sessionValidityPeriod: TimeInterval = 24 * 60 * 60 // 24 hours
        let lastLogin = Date(timeIntervalSince1970: lastLoginTimestamp)

        if Date().timeIntervalSince(lastLogin) < sessionValidityPeriod {
            isAuthenticated = true
            currentUser = UserAccount(
                email: storedEmail,
                name: storedName.isEmpty ? "User" : storedName,
                joinDate: lastLogin,
                subscriptionTier: .free
            )
        }
    }

    func signIn(email: String, password: String) async throws {
        // Simulate API validation delay
        try await Task.sleep(for: .seconds(1.5))

        // Input validation
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidInput
        }

        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }

        // In real app, validate with server
        // For demo, accept any valid email/password combo

        await MainActor.run {
            // Store credentials securely
            try? keychain.store(password: password, for: email)

            // Store non-sensitive data
            storedEmail = email
            storedName = extractNameFromEmail(email)
            lastLoginTimestamp = Date().timeIntervalSince1970

            // Update state
            isAuthenticated = true
            currentUser = UserAccount(
                email: email,
                name: storedName,
                joinDate: Date(),
                subscriptionTier: .free
            )
        }
    }

    func signUp(name: String, email: String, password: String, phoneNumber: String? = nil) async throws {
        // Simulate API call delay
        try await Task.sleep(for: .seconds(2))

        // Comprehensive validation
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidInput
        }

        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        guard isStrongPassword(password) else {
            throw AuthError.weakPassword
        }

        // Validate phone number if provided
        if let phone = phoneNumber, !phone.isEmpty {
            guard isValidPhoneNumber(phone) else {
                throw AuthError.invalidPhone
            }
        }

        // In real app, create account on server

        await MainActor.run {
            // Store credentials securely
            try? keychain.store(password: password, for: email)

            // Store non-sensitive data
            storedEmail = email
            storedName = name
            lastLoginTimestamp = Date().timeIntervalSince1970

            // Update state
            isAuthenticated = true
            currentUser = UserAccount(
                email: email,
                name: name,
                joinDate: Date(),
                subscriptionTier: .free,
                phoneNumber: phoneNumber
            )
        }
    }

    func signInWithBiometrics() async throws {
        guard biometricEnabled && !storedEmail.isEmpty else {
            throw AuthError.biometricNotEnabled
        }

        let success = await biometricAuth.authenticate(reason: "Sign in to ShootVeil")

        if success {
            await MainActor.run {
                isAuthenticated = true
                lastLoginTimestamp = Date().timeIntervalSince1970
                currentUser = UserAccount(
                    email: storedEmail,
                    name: storedName.isEmpty ? "User" : storedName,
                    joinDate: Date(timeIntervalSince1970: lastLoginTimestamp),
                    subscriptionTier: .free
                )
            }
        } else {
            throw AuthError.biometricFailed
        }
    }

    func enableBiometrics() async throws -> Bool {
        guard !storedEmail.isEmpty else {
            throw AuthError.notSignedIn
        }

        let success = await biometricAuth.authenticate(reason: "Enable biometric authentication for ShootVeil")

        if success {
            await MainActor.run {
                biometricEnabled = true
            }
            return true
        }

        return false
    }

    func signOut() {
        // Clear sensitive data from Keychain
        if !storedEmail.isEmpty {
            keychain.delete(for: storedEmail)
        }

        // Clear state
        storedEmail = ""
        storedName = ""
        lastLoginTimestamp = 0
        biometricEnabled = false
        isAuthenticated = false
        currentUser = nil
    }

    func signUpWithGoogle(name: String, email: String, googleID: String) async throws {
        // Simulate API call delay
        try await Task.sleep(for: .seconds(1.5))

        // Validation
        guard !name.isEmpty, !email.isEmpty, !googleID.isEmpty else {
            throw AuthError.invalidInput
        }

        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        // In real app, create account on server with Google credentials

        await MainActor.run {
            // Store Google authentication data
            try? keychain.store(password: googleID, for: "\(email)_google")

            // Store non-sensitive data
            storedEmail = email
            storedName = name
            lastLoginTimestamp = Date().timeIntervalSince1970

            // Update state
            isAuthenticated = true
            currentUser = UserAccount(
                email: email,
                name: name,
                joinDate: Date(),
                subscriptionTier: .free,
                authProvider: .google
            )
        }
    }

    // MARK: - Helper Methods
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func isStrongPassword(_ password: String) -> Bool {
        // At least 8 characters, contains uppercase, lowercase, and number
        let passwordRegEx = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{8,}$"
        let passwordPred = NSPredicate(format: "SELF MATCHES %@", passwordRegEx)
        return passwordPred.evaluate(with: password)
    }

    private func extractNameFromEmail(_ email: String) -> String {
        let username = email.components(separatedBy: "@").first ?? ""
        return username.capitalized.replacingOccurrences(of: ".", with: " ")
    }

    private func isValidPhoneNumber(_ phone: String) -> Bool {
        // Remove all non-digit characters for validation
        let digitsOnly = phone.filter { $0.isNumber }

        // Check if it's a valid length (10-15 digits for international numbers)
        return digitsOnly.count >= 10 && digitsOnly.count <= 15
    }
}

// MARK: - Keychain Manager (Apple Security Best Practice)
class KeychainManager {
    private let service = "com.shootveil.credentials"

    func store(password: String, for account: String) throws {
        let data = password.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw AuthError.keychainError
        }
    }

    func retrieve(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    func hasCredentials(for account: String) -> Bool {
        return retrieve(for: account) != nil
    }
}

// MARK: - Biometric Authentication Manager
class BiometricAuthManager {
    private let context = LAContext()

    func getBiometricType() -> LABiometryType {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        return context.biometryType
    }

    func authenticate(reason: String) async -> Bool {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return success
        } catch {
            return false
        }
    }
}

// MARK: - Enhanced Auth Error Types
enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidEmail
    case invalidInput
    case weakPassword
    case networkError
    case keychainError
    case biometricNotEnabled
    case biometricFailed
    case notSignedIn
    case invalidPhone

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidInput:
            return "Please fill in all fields"
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, and number"
        case .networkError:
            return "Network error. Please try again."
        case .keychainError:
            return "Failed to securely store credentials"
        case .biometricNotEnabled:
            return "Biometric authentication is not enabled"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .notSignedIn:
            return "Please sign in first"
        case .invalidPhone:
            return "Invalid phone number format"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .weakPassword:
            return "Use at least 8 characters including uppercase, lowercase letters, and numbers"
        case .biometricNotEnabled:
            return "Enable biometric authentication in your account settings"
        case .invalidEmail:
            return "Enter a valid email address like example@domain.com"
        default:
            return nil
        }
    }
}

// MARK: - User Account Model
struct UserAccount {
    let email: String
    let name: String
    let joinDate: Date
    let subscriptionTier: SubscriptionTier
    let phoneNumber: String?
    let authProvider: AuthProvider?

    init(email: String, name: String, joinDate: Date, subscriptionTier: SubscriptionTier, phoneNumber: String? = nil, authProvider: AuthProvider? = nil) {
        self.email = email
        self.name = name
        self.joinDate = joinDate
        self.subscriptionTier = subscriptionTier
        self.phoneNumber = phoneNumber
        self.authProvider = authProvider
    }
}

// MARK: - Authentication Flow
struct AuthenticationFlow: View {
    let onAuthenticationSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignUp = false

    var body: some View {
        NavigationView {
            if showingSignUp {
                SignUpView(
                    authManager: AuthenticationManager.shared,
                    onSuccess: onAuthenticationSuccess,
                    onSwitchToSignIn: {
                        showingSignUp = false
                    }
                )
            } else {
                SignInView(
                    onSuccess: onAuthenticationSuccess,
                    onSwitchToSignUp: {
                        showingSignUp = true
                    }
                )
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Sign In View
struct SignInView: View {
    let onSuccess: () -> Void
    let onSwitchToSignUp: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var emailValidationError: String?
    @State private var passwordValidationError: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .accessibilityLabel("Sign in icon")

                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Sign in to your ShootVeil account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Biometric Sign In (if available and enabled)
                if authManager.biometricType != .none && authManager.isAuthenticated == false {
                    BiometricSignInButton(authManager: authManager, onSuccess: onSuccess)
                        .padding(.horizontal, 32)
                }

                // Form
                VStack(spacing: 20) {
                    // Email Field with Validation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Enter your email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .textFieldStyle(AuthTextFieldStyle(hasError: emailValidationError != nil))
                            .onChange(of: email) { oldValue, newValue in
                                validateEmail()
                            }
                            .accessibilityLabel("Email address")
                            .accessibilityHint("Enter your email address")

                        if let emailError = emailValidationError {
                            Text(emailError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Email validation error: \(emailError)")
                        }
                    }

                    // Password Field with Validation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)

                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .textFieldStyle(AuthTextFieldStyle(hasError: passwordValidationError != nil))
                            .onChange(of: password) { oldValue, newValue in
                                validatePassword()
                            }
                            .accessibilityLabel("Password")
                            .accessibilityHint("Enter your password")

                        if let passwordError = passwordValidationError {
                            Text(passwordError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Password validation error: \(passwordError)")
                        }
                    }

                    // Sign In Button
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                                    .accessibilityLabel("Signing in")
                            }

                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !isFormValid)
                    .accessibilityLabel(isLoading ? "Signing in" : "Sign in button")
                    .accessibilityHint("Double tap to sign in with your credentials")

                    // Forgot Password
                    Button("Forgot Password?") {
                        // Handle forgot password
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Forgot password")
                    .accessibilityHint("Tap to reset your password")
                }
                .padding(.horizontal, 32)

                // Switch to Sign Up
                VStack(spacing: 16) {
                    Text("Don't have an account?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: onSwitchToSignUp) {
                        Text("Create Account")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Create account")
                    .accessibilityHint("Switch to account creation")
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Close sign in screen")
            }

            // Keyboard toolbar
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Next") {
                    switch focusedField {
                    case .email:
                        focusedField = .password
                    case .password:
                        focusedField = nil
                    case .none:
                        break
                    default:
                        break
                    }
                }
                .disabled(focusedField == .password)

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            VStack {
                Text(errorMessage)
                if let suggestion = currentAuthError?.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        emailValidationError == nil &&
        passwordValidationError == nil
    }

    private var currentAuthError: AuthError? {
        // Convert error message back to AuthError for recovery suggestions
        return nil // Would implement in real app
    }

    private func validateEmail() {
        if email.isEmpty {
            emailValidationError = nil
        } else if !email.contains("@") || !email.contains(".") {
            emailValidationError = "Please enter a valid email address"
        } else {
            emailValidationError = nil
        }
    }

    private func validatePassword() {
        if password.isEmpty {
            passwordValidationError = nil
        } else if password.count < 8 {
            passwordValidationError = "Password must be at least 8 characters"
        } else {
            passwordValidationError = nil
        }
    }

    private func signIn() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        isLoading = true
        errorMessage = ""
        focusedField = nil

        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    // Success haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Biometric Sign In Button
struct BiometricSignInButton: View {
    @ObservedObject var authManager: AuthenticationManager
    let onSuccess: () -> Void

    @State private var isAuthenticating = false

    var body: some View {
        Button(action: authenticateWithBiometrics) {
            HStack {
                if isAuthenticating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: biometricIcon)
                        .font(.title2)
                }

                Text(biometricText)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isAuthenticating)
        .accessibilityLabel(biometricAccessibilityLabel)
        .accessibilityHint("Use biometric authentication to sign in")
    }

    private var biometricIcon: String {
        switch authManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }

    private var biometricText: String {
        switch authManager.biometricType {
        case .faceID:
            return "Sign in with Face ID"
        case .touchID:
            return "Sign in with Touch ID"
        default:
            return "Sign in with Biometrics"
        }
    }

    private var biometricAccessibilityLabel: String {
        switch authManager.biometricType {
        case .faceID:
            return "Sign in with Face ID"
        case .touchID:
            return "Sign in with Touch ID"
        default:
            return "Sign in with biometric authentication"
        }
    }

    private func authenticateWithBiometrics() {
        isAuthenticating = true

        Task {
            do {
                try await authManager.signInWithBiometrics()
                await MainActor.run {
                    isAuthenticating = false
                    // Success haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Enhanced Auth Text Field Style
struct AuthTextFieldStyle: TextFieldStyle {
    let hasError: Bool

    init(hasError: Bool = false) {
        self.hasError = hasError
    }

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .font(.body)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasError ? Color.red : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: - Current Plan Row Component
struct CurrentPlanRow: View {
    let onUpgradePressed: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Plan icon
            SubscriptionTier.adSupported.icon
                .foregroundColor(.white)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(SubscriptionTier.adSupported.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Plan")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Text(SubscriptionTier.adSupported.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(SubscriptionTier.adSupported.color)

                // Usage indicator
                HStack {
                    Text("Unlimited identifications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Upgrade")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            onUpgradePressed()
        }
    }
}

// MARK: - Enhanced Setting Row with Optional Action
struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    let action: (() -> Void)?

    init(icon: String, title: String, subtitle: String, iconColor: Color, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.action = action
    }

    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Subscription Tier Enum
enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case adSupported = "ad_supported"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free: return "🆓 Free"
        case .adSupported: return "📺 Ad-Supported"
        case .premium: return "💎 Premium"
        }
    }

    var monthlyLimit: Int {
        switch self {
        case .free: return 5
        case .adSupported: return 30
        case .premium: return Int.max // Unlimited
        }
    }

    var price: String {
        switch self {
        case .free: return "Free"
        case .adSupported: return "Free with ads"
        case .premium: return "$3.99/month"
        }
    }

    var color: Color {
        switch self {
        case .free: return .gray
        case .adSupported: return .orange
        case .premium: return .purple
        }
    }

    var icon: Image {
        switch self {
        case .free: return Image(systemName: "hand.wave.fill")
        case .adSupported: return Image(systemName: "tv.fill")
        case .premium: return Image(systemName: "crown.fill")
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "5 identifications per month",
                "Basic AI detection",
                "Location tracking",
                "Photo history"
            ]
        case .adSupported:
            return [
                "30 identifications per month",
                "Enhanced AI detection",
                "Detailed object information",
                "Advanced photo sharing",
                "Shows occasional ads"
            ]
        case .premium:
            return [
                "Unlimited identifications",
                "Premium AI detection",
                "Priority processing",
                "Advanced analytics",
                "No advertisements",
                "Export data features",
                "Priority support"
            ]
        }
    }
}

// MARK: - Plan Selection View
struct PlanSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPlan: SubscriptionTier = .free
    @State private var selectedPlan: SubscriptionTier = .free
    @State private var showingPurchaseConfirmation = false
    @EnvironmentObject var adManager: AdManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)

                        Text("Choose Your Plan")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Unlock the full potential of ShootVeil with AI-powered object identification")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Plan Cards
                    VStack(spacing: 16) {
                        ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                            PlanCard(
                                tier: tier,
                                isSelected: selectedPlan == tier,
                                isCurrent: currentPlan == tier,
                                onSelect: {
                                    selectedPlan = tier
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Action Button
                    if selectedPlan != currentPlan {
                        VStack(spacing: 12) {
                            Button(action: {
                                if selectedPlan == .free {
                                    // Downgrade confirmation
                                    showingPurchaseConfirmation = true
                                } else {
                                    // Upgrade or purchase
                                    showingPurchaseConfirmation = true
                                }
                            }) {
                                HStack {
                                    if selectedPlan == .free {
                                        Text("Downgrade to Free")
                                    } else if selectedPlan.rawValue > currentPlan.rawValue {
                                        Text("Upgrade to \(selectedPlan.displayName)")
                                    } else {
                                        Text("Switch to \(selectedPlan.displayName)")
                                    }

                                    if selectedPlan != .free {
                                        Text("- \(selectedPlan.price)")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(selectedPlan.color)
                                .cornerRadius(12)
                            }

                            Text("Cancel anytime • Secure payments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Confirm Plan Change", isPresented: $showingPurchaseConfirmation) {
            Button("Confirm") {
                // Handle plan change
                currentPlan = selectedPlan
                dismiss()
            }

            Button("Cancel", role: .cancel) {
                selectedPlan = currentPlan
            }
        } message: {
            Text("Are you sure you want to \(selectedPlan == .free ? "downgrade" : "upgrade") to \(selectedPlan.displayName)?")
        }
    }
}

// MARK: - Plan Card Component
struct PlanCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            tier.icon
                                .foregroundColor(tier.color)
                                .font(.title2)

                            Text(tier.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            if isCurrent {
                                Text("CURRENT")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tier.color)
                                    .cornerRadius(8)
                            }
                        }

                        Text(tier.price)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(tier.color)
                    }

                    Spacer()

                    if tier == .premium {
                        VStack {
                            Text("MOST")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                }

                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)

                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? tier.color : (isCurrent ? tier.color.opacity(0.5) : Color.gray.opacity(0.3)),
                        lineWidth: isSelected ? 3 : (isCurrent ? 2 : 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? tier.color.opacity(0.05) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Account Details View
struct AccountDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.largeTitle)

                        VStack(alignment: .leading) {
                            Text(authManager.currentUser?.name ?? "User")
                                .font(.headline)
                            Text(authManager.currentUser?.email ?? "user@example.com")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account Information")
                }

                Section {
                    SettingRow(
                        icon: "envelope.fill",
                        title: "Email Preferences",
                        subtitle: "Manage email notifications",
                        iconColor: .blue
                    )

                    SettingRow(
                        icon: "lock.fill",
                        title: "Privacy Settings",
                        subtitle: "Control your data privacy",
                        iconColor: .green
                    )

                    SettingRow(
                        icon: "arrow.down.circle.fill",
                        title: "Export Data",
                        subtitle: "Download your identification history",
                        iconColor: .orange
                    )
                } header: {
                    Text("Data & Privacy")
                }

                Section {
                    SettingRow(
                        icon: "rectangle.portrait.and.arrow.right.fill",
                        title: "Sign Out",
                        subtitle: "Sign out of your account",
                        iconColor: .orange,
                        action: {
                            showingSignOutConfirmation = true
                        }
                    )

                    SettingRow(
                        icon: "trash.fill",
                        title: "Delete Account",
                        subtitle: "Permanently delete your account",
                        iconColor: .red
                    )
                } header: {
                    Text("Account Actions")
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
                dismiss()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    let onSuccess: () -> Void
    let onSwitchToSignIn: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var nameValidationError: String?
    @State private var emailValidationError: String?
    @State private var passwordValidationError: String?
    @State private var confirmPasswordValidationError: String?
    @State private var phoneValidationError: String?
    @State private var showPasswordRequirements = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, email, phoneNumber, password, confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .accessibilityLabel("Create account icon")

                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Join ShootVeil and unlock intelligent object identification")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Google Sign-In Section
                VStack(spacing: 16) {
                    Text("Quick Sign Up")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)

                    // Google Sign-In Button
                    Button(action: signInWithGoogle) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.white)
                                .font(.title2)

                            Text("Continue with Google")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBlue))
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                    .accessibilityLabel("Sign up with Google")
                    .accessibilityHint("Create account using your Google account")

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        Text("or")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                }

                // Manual Form Section
                VStack(spacing: 20) {
                    Text("Manual Sign Up")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)

                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Enter your name", text: $name)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .focused($focusedField, equals: .name)
                            .textFieldStyle(AuthTextFieldStyle(hasError: nameValidationError != nil))
                            .onChange(of: name) { oldValue, newValue in
                                validateName()
                            }
                            .accessibilityLabel("Full name")
                            .accessibilityHint("Enter your full name")

                        if let nameError = nameValidationError {
                            Text(nameError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Name validation error: \(nameError)")
                        }
                    }

                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Enter your email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .textFieldStyle(AuthTextFieldStyle(hasError: emailValidationError != nil))
                            .onChange(of: email) { oldValue, newValue in
                                validateEmail()
                            }
                            .accessibilityLabel("Email address")
                            .accessibilityHint("Enter your email address")

                        if let emailError = emailValidationError {
                            Text(emailError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Email validation error: \(emailError)")
                        }
                    }

                    // Phone Number Field (Optional)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Phone Number")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("(Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }

                        TextField("Enter your phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focusedField, equals: .phoneNumber)
                            .textFieldStyle(AuthTextFieldStyle(hasError: phoneValidationError != nil))
                            .onChange(of: phoneNumber) { oldValue, newValue in
                                validatePhoneNumber()
                            }
                            .accessibilityLabel("Phone number")
                            .accessibilityHint("Enter your phone number for account recovery")

                        if let phoneError = phoneValidationError {
                            Text(phoneError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Phone validation error: \(phoneError)")
                        } else if phoneNumber.isEmpty {
                            Text("Used for account recovery and important notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Password Field with Strength Indicator
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: {
                                showPasswordRequirements.toggle()
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel("Password requirements")
                            .accessibilityHint("Tap to view password requirements")
                        }

                        SecureField("Create a password", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .textFieldStyle(AuthTextFieldStyle(hasError: passwordValidationError != nil))
                            .onChange(of: password) { oldValue, newValue in
                                validatePassword()
                                validateConfirmPassword()
                            }
                            .accessibilityLabel("Password")
                            .accessibilityHint("Create a strong password")

                        // Password Strength Indicator
                        if !password.isEmpty {
                            PasswordStrengthView(password: password)
                        }

                        if showPasswordRequirements {
                            PasswordRequirementsView(password: password)
                                .transition(.slide)
                        }

                        if let passwordError = passwordValidationError {
                            Text(passwordError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Password validation error: \(passwordError)")
                        }
                    }

                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                            .foregroundColor(.primary)

                        SecureField("Confirm your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .textFieldStyle(AuthTextFieldStyle(hasError: confirmPasswordValidationError != nil))
                            .onChange(of: confirmPassword) { oldValue, newValue in
                                validateConfirmPassword()
                            }
                            .accessibilityLabel("Confirm password")
                            .accessibilityHint("Re-enter your password")

                        if let confirmError = confirmPasswordValidationError {
                            Text(confirmError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Password confirmation error: \(confirmError)")
                        }
                    }

                    // Sign Up Button
                    Button(action: signUp) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                                    .accessibilityLabel("Creating account")
                            }

                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !isFormValid)
                    .accessibilityLabel(isLoading ? "Creating account" : "Create account button")
                    .accessibilityHint("Double tap to create your account")

                    // Terms and Privacy
                    Text("By creating an account, you agree to our [Terms of Service](https://shootveil.ai/terms) and [Privacy Policy](https://shootveil.ai/privacy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityLabel("Legal agreements")
                        .accessibilityHint("Review terms of service and privacy policy")
                }
                .padding(.horizontal, 32)

                // Switch to Sign In
                VStack(spacing: 16) {
                    Text("Already have an account?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: onSwitchToSignIn) {
                        Text("Sign In")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Sign in")
                    .accessibilityHint("Switch to sign in if you already have an account")
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Close account creation screen")
            }

            // Keyboard toolbar
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Next") {
                    switch focusedField {
                    case .name:
                        focusedField = .email
                    case .email:
                        focusedField = .phoneNumber
                    case .phoneNumber:
                        focusedField = .password
                    case .password:
                        focusedField = .confirmPassword
                    case .confirmPassword:
                        focusedField = nil
                    case .none:
                        break
                    }
                }
                .disabled(focusedField == .confirmPassword)

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Account Creation Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            VStack {
                Text(errorMessage)
                if let suggestion = currentAuthError?.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
        .animation(.easeInOut, value: showPasswordRequirements)
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        nameValidationError == nil &&
        emailValidationError == nil &&
        passwordValidationError == nil &&
        confirmPasswordValidationError == nil &&
        phoneValidationError == nil
    }

    private var currentAuthError: AuthError? {
        // Convert error message back to AuthError for recovery suggestions
        return nil // Would implement in real app
    }

    private func validateName() {
        if name.isEmpty {
            nameValidationError = nil
        } else if name.count < 2 {
            nameValidationError = "Name must be at least 2 characters"
        } else {
            nameValidationError = nil
        }
    }

    private func validateEmail() {
        if email.isEmpty {
            emailValidationError = nil
        } else if !email.contains("@") || !email.contains(".") {
            emailValidationError = "Please enter a valid email address"
        } else {
            emailValidationError = nil
        }
    }

    private func validatePhoneNumber() {
        if phoneNumber.isEmpty {
            phoneValidationError = nil
        } else {
            // Remove all non-digit characters for validation
            let digitsOnly = phoneNumber.filter { $0.isNumber }

            if digitsOnly.count < 10 {
                phoneValidationError = "Phone number must be at least 10 digits"
            } else if digitsOnly.count > 15 {
                phoneValidationError = "Phone number is too long"
            } else {
                phoneValidationError = nil
            }
        }
    }

    private func validatePassword() {
        if password.isEmpty {
            passwordValidationError = nil
        } else if password.count < 8 {
            passwordValidationError = "Password must be at least 8 characters"
        } else if !password.contains(where: { $0.isUppercase }) {
            passwordValidationError = "Password must contain uppercase letters"
        } else if !password.contains(where: { $0.isLowercase }) {
            passwordValidationError = "Password must contain lowercase letters"
        } else if !password.contains(where: { $0.isNumber }) {
            passwordValidationError = "Password must contain numbers"
        } else {
            passwordValidationError = nil
        }
    }

    private func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordValidationError = nil
        } else if confirmPassword != password {
            confirmPasswordValidationError = "Passwords do not match"
        } else {
            confirmPasswordValidationError = nil
        }
    }

    private func signInWithGoogle() {
        print("🔐 Starting Google Sign-In process")
        isLoading = true

        // Get the presenting view controller using modern iOS approach
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first,
              let presentingViewController = window.rootViewController else {
            print("❌ Could not get presenting view controller")
            isLoading = false
            return
        }

        // Perform Google Sign-In
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    print("❌ Google Sign-In error: \(error.localizedDescription)")
                    self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    self.showingError = true
                    return
                }

                guard let result = result,
                      let user = result.user,
                      let profile = user.profile else {
                    print("❌ Failed to get user profile from Google")
                    self.errorMessage = "Failed to get user profile from Google"
                    self.showingError = true
                    return
                }

                print("✅ Google Sign-In successful for: \(profile.email)")

                // Store user data
                let name = profile.name
                let email = profile.email
                let googleID = user.userID ?? ""

                // Call authentication manager
                Task {
                    do {
                        try await authManager.signUpWithGoogle(
                            name: name,
                            email: email,
                            googleID: googleID
                        )

                        await MainActor.run {
                            hapticFeedback.notificationOccurred(.success)
                            print("🎉 Google account creation successful")
                        }
                    } catch {
                        await MainActor.run {
                            print("❌ Google account creation failed: \(error.localizedDescription)")
                            self.errorMessage = "Account creation failed: \(error.localizedDescription)"
                            self.showingError = true
                            self.hapticFeedback.notificationOccurred(.error)
                        }
                    }
                }
            }
        }
    }

    private func signUp() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        isLoading = true
        errorMessage = ""
        focusedField = nil

        Task {
            do {
                try await authManager.signUp(
                    name: name,
                    email: email,
                    password: password,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
                )
                await MainActor.run {
                    isLoading = false
                    // Success haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Password Strength Indicator
struct PasswordStrengthView: View {
    let password: String

    private var strength: PasswordStrength {
        getPasswordStrength(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Password Strength:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(strength.description)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(strength.color)

                Spacer()
            }

            // Strength bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(strength.color)
                            .frame(width: geometry.size.width * strength.percentage, height: 4),
                        alignment: .leading
                    )
            }
            .frame(height: 4)
        }
        .accessibilityLabel("Password strength: \(strength.description)")
    }

    private func getPasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*".contains($0) }) { score += 1 }

        switch score {
        case 0...2:
            return .weak
        case 3...4:
            return .medium
        case 5...6:
            return .strong
        default:
            return .weak
        }
    }
}

enum PasswordStrength {
    case weak, medium, strong

    var description: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var percentage: Double {
        switch self {
        case .weak: return 0.33
        case .medium: return 0.66
        case .strong: return 1.0
        }
    }
}

// MARK: - Password Requirements View
struct PasswordRequirementsView: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Requirements:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            RequirementRow(
                text: "At least 8 characters",
                isMet: password.count >= 8
            )

            RequirementRow(
                text: "Contains uppercase letter",
                isMet: password.contains(where: { $0.isUppercase })
            )

            RequirementRow(
                text: "Contains lowercase letter",
                isMet: password.contains(where: { $0.isLowercase })
            )

            RequirementRow(
                text: "Contains number",
                isMet: password.contains(where: { $0.isNumber })
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .primary : .secondary)

            Spacer()
        }
        .accessibilityLabel("\(text): \(isMet ? "met" : "not met")")
    }
}

// MARK: - Auth Provider Enum
enum AuthProvider {
    case email
    case google
    case apple

    var displayName: String {
        switch self {
        case .email:
            return "Email"
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        }
    }
}

#Preview {
    SettingsView()
}
