import Foundation
import FirebaseFirestore

struct ParkingTicket: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let spotId: String
    let startTime: Date
    var endTime: Date?
    var status: String // "active", "paid", "completed"
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

struct Barrier: Identifiable, Codable {
    @DocumentID var id: String?
    var isOpen: Bool
    let name: String // "enterBarrier", "exitBarrier"
    
    enum CodingKeys: String, CodingKey {
        case id
        case isOpen
        case name
    }
}

struct ParkingSpot: Identifiable, Codable {
    @DocumentID var id: String?
    let number: Int
    let section: String
    var occupied: Bool
    var assignedUserId: String?
    
    var displayName: String {
        id ?? "spot\(section)\(number)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case number
        case section
        case occupied
        case assignedUserId
    }
}

struct PaymentCard: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let last4Digits: String  // Only store last 4 for security
    let cardType: String     // "Visa", "Mastercard", "Amex", etc.
    let cardHolderName: String?  // Optional for backwards compatibility
    let expiryMonth: String
    let expiryYear: String
    var isDefault: Bool
    let createdAt: Date?  // Optional for backwards compatibility
    
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
    
    // Custom decoder for backwards compatibility
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
