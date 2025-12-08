import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUserUID: String?
    @Published var currentUserEmail: String?
    @Published var currentUserData: [String: Any]?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @AppStorage("isFaceIDEnabled") var isFaceIDEnabled: Bool = false
    
    // 🔑 1. ADD THE RE-AUTHENTICATION TIME LIMIT
    private let biometricReauthThreshold: TimeInterval = 30.0
    
    private let db = Firestore.firestore(database: "parking")
    
    init() {
        // Check if user is already authenticated on device
        checkAuthState()
    }
    
    // MARK: - Check Auth State on Launch
    
    func checkAuthState() {
        // Check if device has stored auth
        if DeviceAuthManager.isDeviceAuthenticated(),
           let uid = DeviceAuthManager.getAuthenticatedUID(),
           let email = DeviceAuthManager.getAuthenticatedEmail() {
            
            // Check if Firebase session is still valid
            if let currentUser = Auth.auth().currentUser, currentUser.uid == uid {
                print("[Auth] Valid Firebase session found")
                self.isAuthenticated = true
                self.currentUserUID = uid
                self.currentUserEmail = email
                loadUserData(uid: uid)
                
                // 🌟 2. UPDATE TIMESTAMP on successful session check
                DeviceAuthManager.updateLastActiveTimestamp()
                
            } else {
                // Firebase session expired, check for biometric
                if DeviceAuthManager.isBiometricEnabled() {
                    print("[Auth] Firebase session expired, biometric enabled")
                    // Don't auto-authenticate, let IOSApp.swift handle biometric prompt
                } else {
                    print("[Auth] Firebase session expired, clearing device auth")
                    DeviceAuthManager.clearAuthState()
                }
            }
        }
    }
    
    // MARK: - Biometric Re-authentication Check (NEW FUNCTION)
    
    /**
     Determines if biometric re-authentication is necessary based on the time elapsed.
     */
    func checkIfBiometricRequired() -> Bool {
        // 1. Must be enabled for the user AND have saved device credentials
        guard DeviceAuthManager.isBiometricEnabled(),
              DeviceAuthManager.isDeviceAuthenticated() else {
            print("[AuthTimer] Biometric not enabled or no device auth.")
            return false
        }
        
        // 2. Check time elapsed
        guard let lastActive = DeviceAuthManager.getLastActiveTimestamp() else {
            // If no timestamp is saved, require re-auth
            print("[AuthTimer] No last active timestamp found. Re-auth required.")
            return true
        }
        
        let timeSinceLastActive = Date().timeIntervalSince(lastActive)
        
        if timeSinceLastActive > biometricReauthThreshold {
            print("[AuthTimer] Re-auth required. Time elapsed: \(Int(timeSinceLastActive))s.")
            return true
        } else {
            print("[AuthTimer] Re-auth NOT required. Time elapsed: \(Int(timeSinceLastActive))s.")
            return false
        }
    }
    
    
    // MARK: - Face ID / Biometric Methods

    func enableFaceID() async throws {
        // Mark biometric as enabled in device auth
        DeviceAuthManager.setBiometricEnabled(true)
        print("[Auth] Face ID enabled")
    }

    func disableFaceID() async throws {
        // Mark biometric as disabled in device auth
        DeviceAuthManager.setBiometricEnabled(false)
        print("[Auth] Face ID disabled")
    }

    // MARK: - Sign In with Email/Password
    
    func signIn(email: String, password: String, enableBiometric: Bool) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Firebase Authentication
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let user = result.user
            
            print("[Auth] Sign in successful for: \(user.email ?? "unknown")")
            
            // Fetch user data from Firestore
            let userDoc = try await db.collection("Users").document(user.uid).getDocument()
            
            var userData: [String: Any]?
            
            if userDoc.exists {
                userData = userDoc.data()
            } else {
                // Profile missing, create default
                print("[Auth] User profile missing, creating default.")
                let newProfile: [String: Any] = [
                    "uid": user.uid,
                    "email": email,
                    "displayName": "User",
                    "role": "user",
                    "isActive": true,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                try await db.collection("Users").document(user.uid).setData(newProfile)
                userData = newProfile
            }
            
            // Check if user is active
            if let isActive = userData?["isActive"] as? Bool, !isActive {
                // Sign out immediately
                try Auth.auth().signOut()
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Your account has been disabled. Please contact HR."])
            }
            
            // All roles are allowed: Employee, Manager, HR, Admin, CEO
            // No role restriction check needed
            
            // Save to device
            DeviceAuthManager.saveAuthState(uid: user.uid, email: email)
            
            // Handle biometric enrollment
            // Biometric check removed
            if enableBiometric {
                let saved = KeychainManager.shared.saveCredentials(email: email, password: password)
                if saved {
                    DeviceAuthManager.setBiometricEnabled(true)
                    print("[Auth] Biometric credentials saved")
                }
            }
            
            // 🌟 3. UPDATE TIMESTAMP on successful manual sign-in
            DeviceAuthManager.updateLastActiveTimestamp()
            
            // Update state
            self.currentUserUID = user.uid
            self.currentUserEmail = email
            self.currentUserData = userData
            self.isAuthenticated = true
            self.isLoading = false
            
        } catch let error as NSError {
            isLoading = false
            
            // Map Firebase errors to user-friendly messages
            switch error.code {
            case AuthErrorCode.wrongPassword.rawValue:
                errorMessage = "Incorrect password. Please try again."
            case AuthErrorCode.invalidEmail.rawValue:
                errorMessage = "Invalid email address format."
            case AuthErrorCode.userNotFound.rawValue:
                errorMessage = "No account found with this email."
            case AuthErrorCode.userDisabled.rawValue:
                errorMessage = "Your account has been disabled."
            case AuthErrorCode.networkError.rawValue:
                errorMessage = "Network error. Check your connection."
            case AuthErrorCode.tooManyRequests.rawValue:
                errorMessage = "Too many attempts. Please try again later."
            default:
                errorMessage = error.localizedDescription
            }
            
            throw error
        }
    }
    
    // MARK: - Sign In with Biometric
    
    // MARK: - Sign In with Biometric
    
    // Biometric authentication removed
    /*
    func signInWithBiometric() async throws {
        // ... removed ...
    }
    */
    
    // MARK: - Send Password Reset Email
    
    func sendPasswordResetEmail(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("[Auth] Password reset email sent to: \(email)")
        } catch {
            print("[Auth] Error sending password reset: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sign Up (Create Account)
    
    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create user in Firebase Auth
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = result.user
            
            print("[Auth] Sign up successful for: \(user.email ?? "unknown")")
            
            // Create user profile in Firestore
            let newProfile: [String: Any] = [
                "uid": user.uid,
                "email": email,
                "displayName": displayName.isEmpty ? "User" : displayName,
                "role": "user",
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await db.collection("Users").document(user.uid).setData(newProfile)
            
            // Save to device
            DeviceAuthManager.saveAuthState(uid: user.uid, email: email)
            DeviceAuthManager.updateLastActiveTimestamp()
            
            // Update state
            self.currentUserUID = user.uid
            self.currentUserEmail = email
            self.currentUserData = newProfile
            self.isAuthenticated = true
            self.isLoading = false
            
        } catch let error as NSError {
            isLoading = false
            
            // Map Firebase errors to user-friendly messages
            switch error.code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                errorMessage = "This email is already registered. Please sign in."
            case AuthErrorCode.invalidEmail.rawValue:
                errorMessage = "Invalid email address format."
            case AuthErrorCode.weakPassword.rawValue:
                errorMessage = "Password is too weak. Use at least 6 characters."
            case AuthErrorCode.networkError.rawValue:
                errorMessage = "Network error. Check your connection."
            default:
                errorMessage = error.localizedDescription
            }
            
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            DeviceAuthManager.clearAuthState()
            
            self.isAuthenticated = false
            self.currentUserUID = nil
            self.currentUserEmail = nil
            self.currentUserData = nil
            
            print("[Auth] User signed out successfully")
        } catch {
            print("[Auth] Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load User Data from Firestore
    
    private func loadUserData(uid: String) {
        db.collection("Users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[Auth] Error loading user data: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                Task { @MainActor in
                    self.currentUserData = data
                }
                print("[Auth] User data loaded: \(data["displayName"] ?? "Unknown")")
            }
        }
    }
    
    // MARK: - Helper: Should Show Password Change Prompt
    
    func shouldShowPasswordChangePrompt() -> Bool {
        return !DeviceAuthManager.hasSeenPasswordPrompt()
    }
    
    func markPasswordPromptSeen() {
        DeviceAuthManager.setHasSeenPasswordPrompt(true)
    }
    // MARK: - Logout Button Helper
    func logoutButtonView() -> some View {
        Button(action: {
            self.signOut()
        }) {
            Text("Logout")
                .font(.headline)
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Update Display Name
    
    func updateDisplayName(name: String) async throws {
        guard let uid = currentUserUID else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update Firestore
            try await db.collection("Users").document(uid).updateData([
                "displayName": name
            ])
            
            // Reload user data to refresh UI
            loadUserData(uid: uid)
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
