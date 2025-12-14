/*
 * HomeViewModel.swift
 * Smart Parking System
 * Author: Darius Toasca
 * 
 * This is the main view model for the home screen. It manages:
 * - Parking spot availability
 * - Active ticket status
 * - Entry/exit button flows
 * - Real-time Firestore listeners
 */

import Foundation
import FirebaseFirestore
import FirebaseFunctions
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    
    // MARK: - Published State
    // These properties update the UI automatically when changed
    
    @Published var activeTicket: ParkingTicket?
    @Published var userName: String = "User"
    @Published var recentlyPaidTicket: ParkingTicket?
    @Published var occupiedSpots: [ParkingSpot] = []
    @Published var barrierOpening = false
    @Published var barrierSuccess = false
    @Published var remainingTime: Int = 0  // minutes left for exit window
    
    // Entry flow state
    @Published var isPendingEntry = false
    @Published var entryRemainingTime: Int = 60
    @Published var entryRequestError: String?
    @Published var entrySuccess = false
    
    // Exit flow state
    @Published var isPendingExit = false
    @Published var exitRemainingTime: Int = 60
    
    // MARK: - Constants
    
    let totalSpots = 5  // physical parking spots in the lot
    
    // MARK: - Private Properties
    
    private var entryTimer: Timer?
    private var exitTimer: Timer?
    private let db = Firestore.firestore(database: "parking")
    private lazy var functions = Functions.functions(region: "europe-central2")
    
    // Firestore listeners
    private var spotsListener: ListenerRegistration?
    private var ticketListener: ListenerRegistration?
    private var paidTicketListener: ListenerRegistration?
    private var pendingEntryListener: ListenerRegistration?
    
    // MARK: - Computed Properties
    
    // Percentage of spots currently occupied (for progress bar)
    var occupancyRate: Double {
        guard totalSpots > 0 else { return 0 }
        return Double(occupiedSpots.count) / Double(totalSpots)
    }
    
    // How many spots are free
    var availableSpots: Int {
        totalSpots - occupiedSpots.count
    }
    
    // Show exit button if ticket was paid within last 15 minutes
    var canOpenBarrier: Bool {
        guard let ticket = recentlyPaidTicket,
              let paidAt = ticket.endTime else { return false }
        
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        return paidAt > fifteenMinutesAgo && !barrierSuccess
    }
    
    // Show enter button only when appropriate
    // Hidden if: already has ticket, pending entry, entry success, no spots,
    // exit flow active, or barrier just opened
    var canEnterParking: Bool {
        return activeTicket == nil && !isPendingEntry && !entrySuccess &&
               availableSpots > 0 && !canOpenBarrier && !barrierSuccess && !isPendingExit
    }
    
    // Updates the minutes remaining in exit window
    func updateRemainingTime() {
        guard let ticket = recentlyPaidTicket,
              let paidAt = ticket.endTime else {
            remainingTime = 0
            return
        }
        
        let fifteenMinutesAfterPayment = paidAt.addingTimeInterval(15 * 60)
        remainingTime = max(0, Int(fifteenMinutesAfterPayment.timeIntervalSince(Date()) / 60))
    }
    
    // MARK: - Initialization
    
    init() {
        // Listeners are started when user logs in
    }
    
    // MARK: - Listener Setup
    // These functions set up real-time listeners to Firestore collections.
    // The listeners update our @Published properties when data changes.
    
    func startListening(userId: String?) {
        guard let uid = userId else { return }
        
        listenToOccupiedSpots()
        listenToActiveTicket(userId: uid)
        listenToRecentlyPaidTicket(userId: uid)
        listenToPendingEntry(userId: uid)
        fetchUserName(userId: uid)
    }
    
    func stopListening() {
        spotsListener?.remove()
        ticketListener?.remove()
        paidTicketListener?.remove()
        pendingEntryListener?.remove()
        entryTimer?.invalidate()
        exitTimer?.invalidate()
    }
    
    // MARK: - Spot Availability Listener
    // Tracks which spots are currently occupied
    
    private func listenToOccupiedSpots() {
        spotsListener = db.collection("ParkingSpots")
            .whereField("occupied", isEqualTo: true)
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
    
    // MARK: - Active Ticket Listener
    // Watches for user's active parking ticket
    
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
                        
                        // Entry was successful if we were waiting and got a ticket
                        if self.isPendingEntry {
                            self.isPendingEntry = false
                            self.entrySuccess = true
                            self.entryTimer?.invalidate()
                            
                            // Hide success message after 5 seconds
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
    
    // MARK: - Pending Entry Listener
    // Watches if user has requested entry but hasn't pressed button yet
    
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
                        self.isPendingEntry = false
                        self.entryTimer?.invalidate()
                    }
                }
            }
    }
    
    // MARK: - Paid Ticket Listener
    // Watches for recently paid tickets to show exit button
    // Ticket must be paid within last 15 minutes
    
    private func listenToRecentlyPaidTicket(userId: String) {
        paidTicketListener = db.collection("ParkingTickets")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "paid")
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
                        
                        if let paidAt = document.data()["paidAt"] as? Timestamp {
                            let paidAtDate = paidAt.dateValue()
                            let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
                            
                            if paidAtDate > fifteenMinutesAgo {
                                var updatedTicket = ticket
                                updatedTicket.endTime = paidAtDate
                                self.recentlyPaidTicket = updatedTicket
                                self.updateRemainingTime()
                            } else {
                                // Ticket expired - mark as expired in database
                                self.db.collection("ParkingTickets").document(document.documentID).updateData([
                                    "status": "expired"
                                ])
                                self.recentlyPaidTicket = nil
                                self.remainingTime = 0
                            }
                        } else {
                            self.recentlyPaidTicket = ticket
                            self.updateRemainingTime()
                        }
                    } catch {
                        print("Error decoding paid ticket: \(error)")
                    }
                } else {
                    self.recentlyPaidTicket = nil
                    self.remainingTime = 0
                }
            }
    }
    
    // Fetches user's display name for greeting
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
    
    // MARK: - Entry Flow
    // User taps "Enter Parking" -> calls cloud function -> waits for button press
    // Flow: requestParkingEntry -> 60 second countdown -> confirmParkingEntry (Raspberry Pi)
    
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
                
                self.startEntryTimer()
                print("Entry request successful, waiting for barrier button...")
            }
        }
    }
    
    private func startEntryTimer() {
        entryRemainingTime = 60
        entryTimer?.invalidate()
        
        // Countdown 60 seconds
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
    
    // MARK: - Exit Flow
    // User taps "Open Exit Barrier" -> calls cloud function -> waits for button press
    // Flow: requestParkingExit -> 60 second countdown -> confirmParkingExit (Raspberry Pi)
    
    func openBarrier() {
        barrierOpening = true
        isPendingExit = true
        exitRemainingTime = 60
        
        functions.httpsCallable("requestParkingExit").call([:]) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.barrierOpening = false
                
                if let error = error {
                    self.isPendingExit = false
                    print("Error requesting exit: \(error)")
                    return
                }
                
                self.startExitTimer()
                print("Exit request successful, waiting for barrier button...")
            }
        }
    }
    
    private func startExitTimer() {
        exitRemainingTime = 60
        exitTimer?.invalidate()
        
        // Countdown 60 seconds
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
        
        // Listen for barrier to actually open
        db.collection("Barrier").document("exitBarrier")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let isOpen = snapshot?.data()?["isOpen"] as? Bool, isOpen {
                    Task { @MainActor in
                        self.isPendingExit = false
                        self.exitTimer?.invalidate()
                        self.barrierSuccess = true
                        
                        // Hide success and clear ticket after 10 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            self.recentlyPaidTicket = nil
                            self.barrierSuccess = false
                        }
                    }
                }
            }
    }
}
