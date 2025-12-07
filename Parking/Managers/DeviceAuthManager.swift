//
// DeviceAuthManager 2.swift
// HQManagement
//
// Created by Darius Toasca on 12.11.2025.
//


import Foundation
import UIKit

/// Manages device-based authentication persistence
class DeviceAuthManager {
    
    private static let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private static let isAuthenticatedKey = "isDeviceAuthenticated"
    private static let authenticatedUIDKey = "authenticatedUID"
    private static let authenticatedEmailKey = "authenticatedEmail"
    private static let deviceIDKey = "deviceIdentifier"
    private static let biometricEnabledKey = "biometricEnabled"
    private static let hasSeenPasswordPromptKey = "hasSeenPasswordPrompt"
    
    // 🔑 NEW KEY: To store the last successful authentication time
    private static let lastActiveTimestampKey = "lastActiveTimestamp"
    
    // MARK: - Device Identifier
    
    static func getDeviceID() -> String {
        // Try to retrieve existing device ID
        if let existingID = userDefaults.string(forKey: deviceIDKey) {
            return existingID
        }
        
        // Generate new device ID using vendor identifier
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        userDefaults.set(deviceID, forKey: deviceIDKey)
        return deviceID
    }
    
    // MARK: - Save Authentication State
    
    static func saveAuthState(uid: String, email: String) {
        userDefaults.set(true, forKey: isAuthenticatedKey)
        userDefaults.set(uid, forKey: authenticatedUIDKey)
        userDefaults.set(email, forKey: authenticatedEmailKey)
        
        // 🌟 IMPORTANT: Call the new function to update the timestamp
        updateLastActiveTimestamp()
        
        print("[DeviceAuth] Auth state saved for UID: \(uid)")
    }
    
    // MARK: - Check Authentication
    
    static func isDeviceAuthenticated() -> Bool {
        return userDefaults.bool(forKey: isAuthenticatedKey)
    }
    
    static func getAuthenticatedUID() -> String? {
        return userDefaults.string(forKey: authenticatedUIDKey)
    }
    
    static func getAuthenticatedEmail() -> String? {
        return userDefaults.string(forKey: authenticatedEmailKey)
    }
    
    // MARK: - Clear Authentication
    
    static func clearAuthState() {
        userDefaults.removeObject(forKey: isAuthenticatedKey)
        userDefaults.removeObject(forKey: authenticatedUIDKey)
        userDefaults.removeObject(forKey: authenticatedEmailKey)
        userDefaults.removeObject(forKey: biometricEnabledKey)
        userDefaults.removeObject(forKey: hasSeenPasswordPromptKey)
        
        // ❌ You should also clear the timestamp on sign out
        userDefaults.removeObject(forKey: lastActiveTimestampKey)
        
        // Also clear keychain credentials
        KeychainManager.shared.deleteCredentials()
        
        print("[DeviceAuth] Auth state cleared")
    }
    
    // MARK: - Biometric Settings
    
    static func setBiometricEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: biometricEnabledKey)
        print("[DeviceAuth] Biometric enabled: \(enabled)")
    }
    
    static func isBiometricEnabled() -> Bool {
        return userDefaults.bool(forKey: biometricEnabledKey)
    }
    
    // MARK: - Last Active Timestamp (NEW LOGIC)
    
    /// Updates the timestamp to the current time, marking the last activity.
    static func updateLastActiveTimestamp() {
        userDefaults.set(Date(), forKey: lastActiveTimestampKey)
        print("[DeviceAuth] Updated last active timestamp.")
    }
    
    /// Retrieves the time of the last successful authentication.
    static func getLastActiveTimestamp() -> Date? {
        return userDefaults.object(forKey: lastActiveTimestampKey) as? Date
    }
    
    // MARK: - Password Change Prompt Tracking
    
    static func setHasSeenPasswordPrompt(_ seen: Bool) {
        userDefaults.set(seen, forKey: hasSeenPasswordPromptKey)
    }
    
    static func hasSeenPasswordPrompt() -> Bool {
        return userDefaults.bool(forKey: hasSeenPasswordPromptKey)
    }
}
