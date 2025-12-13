import Foundation
import FirebaseFirestore
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // Removed availableSpotsCount, replaced by occupiedSpots and availableSpots
    @Published var activeTicket: ParkingTicket?
    @Published var userName: String = "User"
    @Published var recentlyPaidTicket: ParkingTicket?
    @Published var occupiedSpots: [ParkingSpot] = []
    @Published var barrierOpening = false
    @Published var barrierSuccess = false
    @Published var remainingTime: Int = 0 // Added to track occupied spots

    let totalSpots = 5 // 1 column x 5 rows

    var occupancyRate: Double {
        guard totalSpots > 0 else { return 0 }
        return Double(occupiedSpots.count) / Double(totalSpots)
    }

    var availableSpots: Int {
        totalSpots - occupiedSpots.count
    }

    var canOpenBarrier: Bool {
        guard let ticket = recentlyPaidTicket,
              let paidAt = ticket.endTime else { return false }

        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        return paidAt > fifteenMinutesAgo && !barrierSuccess
    }
    
    func updateRemainingTime() {
        guard let ticket = recentlyPaidTicket,
              let paidAt = ticket.endTime else { 
            remainingTime = 0
            return 
        }
        
        let fifteenMinutesAfterPayment = paidAt.addingTimeInterval(15 * 60)
        remainingTime = max(0, Int(fifteenMinutesAfterPayment.timeIntervalSince(Date()) / 60))
    }

    private let db = Firestore.firestore(database: "parking")
    // Removed cancellables
    private var spotsListener: ListenerRegistration?
    private var ticketListener: ListenerRegistration?
    private var paidTicketListener: ListenerRegistration? // Added for recently paid tickets

    init() {
        // Start listening when initialized
    }

    func startListening(userId: String?) { // Changed userId to optional
        guard let uid = userId else { return }

        listenToOccupiedSpots() // Renamed from listenToSpots
        listenToActiveTicket(userId: uid)
        listenToRecentlyPaidTicket(userId: uid) // Added new listener
        fetchUserName(userId: uid)
    }

    func stopListening() {
        spotsListener?.remove()
        ticketListener?.remove()
        paidTicketListener?.remove() // Added to remove paid ticket listener
        // Removed setting listeners to nil, as remove() is sufficient
    }

    private func listenToOccupiedSpots() { // Renamed from listenToSpots
        spotsListener = db.collection("ParkingSpots")
            .whereField("occupied", isEqualTo: true) // Changed to listen for occupied spots
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to spots: \(error)")
                    return
                }

                self.occupiedSpots = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: ParkingSpot.self)
                } ?? []
            }
    }

    private func listenToActiveTicket(userId: String) {
        ticketListener = db.collection("ParkingTickets")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to tickets: \(error)")
                    return
                }

                if let document = snapshot?.documents.first {
                    do {
                        self.activeTicket = try document.data(as: ParkingTicket.self)
                    } catch {
                        print("Error decoding ticket: \(error)")
                    }
                } else {
                    self.activeTicket = nil
                }
            }
    }

    private func listenToRecentlyPaidTicket(userId: String) {
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)

        paidTicketListener = db.collection("ParkingTickets")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "paid")
            .whereField("paidAt", isGreaterThan: Timestamp(date: fifteenMinutesAgo))
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to paid tickets: \(error)")
                    return
                }

                if let document = snapshot?.documents.first {
                    do {
                        let ticket = try document.data(as: ParkingTicket.self)
                        // Set endTime from paidAt timestamp
                        if let paidAt = document.data()["paidAt"] as? Timestamp {
                            var updatedTicket = ticket
                            updatedTicket.endTime = paidAt.dateValue()
                            self.recentlyPaidTicket = updatedTicket
                        } else {
                            self.recentlyPaidTicket = ticket
                        }
                        // Update remaining time after setting ticket
                        self.updateRemainingTime()
                    } catch {
                        print("Error decoding paid ticket: \(error)")
                    }
                } else {
                    self.recentlyPaidTicket = nil
                    self.remainingTime = 0
                }
            }
    }

    private func fetchUserName(userId: String) {
        db.collection("Users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data(), let name = data["displayName"] as? String {
                Task { @MainActor in
                    self.userName = name
                }
            }
        }
    }

    func openBarrier() {
        barrierOpening = true
        
        // Open the barrier
        db.collection("Barrier").document("exitBarrier").updateData([
            "isOpen": true,
            "lastOpenedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.barrierOpening = false
                
                if let error = error {
                    print("Error opening barrier: \(error)")
                } else {
                    self.barrierSuccess = true
                    print("Exit barrier opened successfully - will close in 30 seconds")
                    
                    // Update ticket status to completed so it doesn't show again
                    if let ticketId = self.recentlyPaidTicket?.id {
                        self.db.collection("ParkingTickets").document(ticketId).updateData([
                            "status": "completed"
                        ]) { error in
                            if let error = error {
                                print("Error updating ticket status: \(error)")
                            } else {
                                print("Ticket marked as completed")
                            }
                        }
                    }
                    
                    // Close barrier after 30 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        self.db.collection("Barrier").document("exitBarrier").updateData([
                            "isOpen": false
                        ]) { error in
                            if let error = error {
                                print("Error closing barrier: \(error)")
                            } else {
                                print("Barrier closed automatically after 30 seconds")
                            }
                        }
                    }
                    
                    // Hide success button after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        self.recentlyPaidTicket = nil
                        self.barrierSuccess = false
                    }
                }
            }
        }
    }
}
