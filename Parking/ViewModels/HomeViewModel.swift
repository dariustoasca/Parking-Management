import Foundation
import FirebaseFirestore
import FirebaseFunctions
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
    
    // Entry-related state
    @Published var isPendingEntry = false
    @Published var entryRemainingTime: Int = 60
    @Published var entryRequestError: String?
    @Published var entrySuccess = false
    
    // Exit-related state (new flow)
    @Published var isPendingExit = false
    @Published var exitRemainingTime: Int = 60

    let totalSpots = 5 // 1 column x 5 rows
    
    private var entryTimer: Timer?
    private var exitTimer: Timer?

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
    
    var canEnterParking: Bool {
        return activeTicket == nil && !isPendingEntry && !entrySuccess && availableSpots > 0 && !canOpenBarrier && !barrierSuccess && !isPendingExit
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
    private lazy var functions = Functions.functions(region: "europe-central2")
    // Removed cancellables
    private var spotsListener: ListenerRegistration?
    private var ticketListener: ListenerRegistration?
    private var paidTicketListener: ListenerRegistration? // Added for recently paid tickets
    private var pendingEntryListener: ListenerRegistration?

    init() {
        // Start listening when initialized
    }

    func startListening(userId: String?) { // Changed userId to optional
        guard let uid = userId else { return }

        listenToOccupiedSpots() // Renamed from listenToSpots
        listenToActiveTicket(userId: uid)
        listenToRecentlyPaidTicket(userId: uid) // Added new listener
        listenToPendingEntry(userId: uid)
        fetchUserName(userId: uid)
    }

    func stopListening() {
        spotsListener?.remove()
        ticketListener?.remove()
        paidTicketListener?.remove() // Added to remove paid ticket listener
        pendingEntryListener?.remove()
        entryTimer?.invalidate()
        exitTimer?.invalidate()
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
                        // If we just got a ticket, entry was successful
                        if self.isPendingEntry {
                            self.isPendingEntry = false
                            self.entrySuccess = true
                            self.entryTimer?.invalidate()
                            // Hide success after 5 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                self.entrySuccess = false
                            }
                        }
                    } catch {
                        print("Error decoding ticket: \(error)")
                    }
                } else {
                    self.activeTicket = nil
                }
            }
    }
    
    private func listenToPendingEntry(userId: String) {
        pendingEntryListener = db.collection("PendingEntry").document("current")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let data = snapshot?.data(),
                   let pendingUserId = data["pendingUserId"] as? String,
                   pendingUserId == userId {
                    // We have a pending entry
                    if !self.isPendingEntry {
                        self.isPendingEntry = true
                        self.startEntryTimer()
                    }
                } else {
                    // No pending entry for us
                    if self.isPendingEntry && self.activeTicket == nil {
                        // Entry expired without ticket creation
                        self.isPendingEntry = false
                        self.entryTimer?.invalidate()
                    }
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
                            
                            // Check if ticket should be expired (15 minutes passed)
                            let expirationTime = paidAt.dateValue().addingTimeInterval(15 * 60)
                            if Date() > expirationTime {
                                // Expire the ticket
                                self.db.collection("ParkingTickets").document(document.documentID).updateData([
                                    "status": "expired"
                                ])
                                self.recentlyPaidTicket = nil
                            }
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
    
    // MARK: - Entry Functions
    
    func requestParkingEntry() {
        isPendingEntry = true
        entryRequestError = nil
        entryRemainingTime = 60
        
        functions.httpsCallable("requestParkingEntry").call([:]) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.isPendingEntry = false
                    self.entryRequestError = error.localizedDescription
                    print("Error requesting entry: \(error)")
                    return
                }
                
                // Start countdown timer
                self.startEntryTimer()
                print("Entry request successful, waiting for barrier button...")
            }
        }
    }
    
    private func startEntryTimer() {
        entryRemainingTime = 60
        entryTimer?.invalidate()
        entryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.entryRemainingTime -= 1
                if self.entryRemainingTime <= 0 {
                    self.entryTimer?.invalidate()
                    self.isPendingEntry = false
                }
            }
        }
    }
    
    // MARK: - Exit Functions (Updated to use new cloud function)

    func openBarrier() {
        barrierOpening = true
        isPendingExit = true
        exitRemainingTime = 60
        
        // Call the new cloud function
        functions.httpsCallable("requestParkingExit").call([:]) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.barrierOpening = false
                
                if let error = error {
                    self.isPendingExit = false
                    print("Error requesting exit: \(error)")
                    return
                }
                
                // Start exit timer
                self.startExitTimer()
                print("Exit request successful, waiting for barrier button...")
            }
        }
    }
    
    private func startExitTimer() {
        exitRemainingTime = 60
        exitTimer?.invalidate()
        exitTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.exitRemainingTime -= 1
                if self.exitRemainingTime <= 0 {
                    self.exitTimer?.invalidate()
                    self.isPendingExit = false
                }
            }
        }
        
        // Also listen for barrier opening
        db.collection("Barrier").document("exitBarrier")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let isOpen = snapshot?.data()?["isOpen"] as? Bool, isOpen {
                    Task { @MainActor in
                        self.isPendingExit = false
                        self.exitTimer?.invalidate()
                        self.barrierSuccess = true
                        
                        // Hide success after 10 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            self.recentlyPaidTicket = nil
                            self.barrierSuccess = false
                        }
                    }
                }
            }
    }
}
