/*
 * ParkingModels.swift
 * Smart Parking System
 * Author: Darius Toasca
 * 
 * This file contains all the data models used in the app.
 * They conform to Codable for Firestore decoding and Identifiable for SwiftUI lists.
 * 
 * MODELS:
 * - ParkingTicket: represents a parking session
 * - Barrier: enter/exit barrier state
 * - ParkingSpot: individual parking space
 * - PaymentCard: saved credit card info (only last 4 digits stored)
 */

import Foundation
import FirebaseFirestore

// MARK: - Parking Ticket
// Represents a single parking session from entry to exit

struct ParkingTicket: Identifiable, Codable {
    @DocumentID var id: String?  // Firestore document ID (e.g., TKT-2025-123)
    let userId: String
    let spotId: String
    let startTime: Date
    var endTime: Date?  // nil while parking, set when paid
    var status: String  // "active" -> "paid" -> "completed"
    var amount: Double
    var qrCodeData: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case spotId
        case startTime
        case endTime
        case status
        case amount
        case qrCodeData
    }
}

// MARK: - Barrier
// Represents the physical entry/exit barriers controlled by Raspberry Pi

struct Barrier: Identifiable, Codable {
    @DocumentID var id: String?
    var isOpen: Bool
    let name: String  // "enterBarrier" or "exitBarrier"
    
    enum CodingKeys: String, CodingKey {
        case id
        case isOpen
        case name
    }
}

// MARK: - Parking Spot
// Represents one of the 5 physical parking spaces in the lot

struct ParkingSpot: Identifiable, Codable {
    @DocumentID var id: String?
    let number: Int
    var section: String?  // legacy field, no longer used
    var occupied: Bool
    var assignedUserId: String?
    
    // Friendly display name for UI
    var displayName: String {
        if let spotId = id, spotId.hasPrefix("spot") {
            let numPart = spotId.dropFirst(4)
            if let lastDigit = numPart.last {
                return "Spot \(lastDigit)"
            }
        }
        return "Spot \(number)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case number
        case section
        case occupied
        case assignedUserId
    }
}

// MARK: - Payment Card
// Stores saved credit card info. For security, only the last 4 digits are saved.
// Full card numbers are never stored in our database.

struct PaymentCard: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let last4Digits: String
    let cardType: String  // Visa, Mastercard, etc.
    let cardHolderName: String?
    let expiryMonth: String
    let expiryYear: String
    var isDefault: Bool
    let createdAt: Date?
    
    var displayName: String {
        "\(cardType) •••• \(last4Digits)"
    }
    
    var expiryDisplay: String {
        "\(expiryMonth)/\(expiryYear)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case last4Digits
        case cardType
        case cardHolderName
        case expiryMonth
        case expiryYear
        case isDefault
        case createdAt
    }
    
    // Custom decoder handles missing fields in old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        last4Digits = try container.decodeIfPresent(String.self, forKey: .last4Digits) ?? ""
        cardType = try container.decodeIfPresent(String.self, forKey: .cardType) ?? "Card"
        cardHolderName = try container.decodeIfPresent(String.self, forKey: .cardHolderName)
        expiryMonth = try container.decodeIfPresent(String.self, forKey: .expiryMonth) ?? ""
        expiryYear = try container.decodeIfPresent(String.self, forKey: .expiryYear) ?? ""
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}
