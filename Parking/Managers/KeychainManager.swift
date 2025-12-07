//
//  KeychainManager.swift
//  HQManagement
//
//  Created by Darius Toasca on 12.11.2025.
//


import Foundation
import Security

/// Secure storage for credentials in iOS Keychain
class KeychainManager {
    
    static let shared = KeychainManager()
    private init() {}
    
    private let service = "com.smarthq.employee"
    
    // MARK: - Save Credentials
    
    func saveCredentials(email: String, password: String) -> Bool {
        // First, delete any existing credentials
        deleteCredentials()
        
        guard let passwordData = password.data(using: .utf8) else {
            print("[Keychain] Failed to encode password")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecValueData as String: passwordData
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("[Keychain] Credentials saved successfully")
            return true
        } else {
            print("[Keychain] Failed to save credentials: \(status)")
            return false
        }
    }
    
    // MARK: - Retrieve Credentials
    
    func retrieveCredentials() -> (email: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let existingItem = item as? [String: Any],
              let email = existingItem[kSecAttrAccount as String] as? String,
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            print("[Keychain] Failed to retrieve credentials: \(status)")
            return nil
        }
        
        print("[Keychain] Credentials retrieved successfully")
        return (email, password)
    }
    
    // MARK: - Delete Credentials
    
    func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] Credentials deleted or not found")
        } else {
            print("[Keychain] Failed to delete credentials: \(status)")
        }
    }
    
    // MARK: - Check if Credentials Exist
    
    func hasCredentials() -> Bool {
        return retrieveCredentials() != nil
    }
}