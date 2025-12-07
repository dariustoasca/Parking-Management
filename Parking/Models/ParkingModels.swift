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
        "\(section)\(number)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case number
        case section
        case occupied
        case assignedUserId
    }
}
