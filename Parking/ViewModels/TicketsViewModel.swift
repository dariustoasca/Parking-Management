import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TicketsViewModel: ObservableObject {
    @Published var activeTickets: [ParkingTicket] = []
    @Published var historyTickets: [ParkingTicket] = []
    @Published var isLoading = false
    
    private var db = Firestore.firestore(database: "parking")
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        isLoading = true
        print("🎫 [TicketsViewModel] Starting to listen for userId: \(userId)")
        
        listener = db.collection("ParkingTickets")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("❌ [TicketsViewModel] Error fetching tickets: \(error.localizedDescription)")
                    // If index error, try without ordering
                    if error.localizedDescription.contains("index") {
                        print("⚠️ [TicketsViewModel] Index missing! Trying fallback query...")
                        self.startListeningFallback(userId: userId)
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [TicketsViewModel] No documents in snapshot")
                    return
                }
                
                print("📄 [TicketsViewModel] Found \(documents.count) ticket documents")
                
                let allTickets = documents.compactMap { doc -> ParkingTicket? in
                    do {
                        let ticket = try doc.data(as: ParkingTicket.self)
                        print("  ✅ Ticket: \(ticket.id ?? "no-id") status: \(ticket.status)")
                        return ticket
                    } catch {
                        print("  ❌ Failed to decode ticket: \(error)")
                        return nil
                    }
                }
                
                self.activeTickets = allTickets.filter { $0.status == "active" || $0.status == "paid" }
                self.historyTickets = allTickets.filter { $0.status == "completed" }
                
                print("📊 [TicketsViewModel] Active: \(self.activeTickets.count), History: \(self.historyTickets.count)")
            }
    }
    
    // Fallback query without ordering (in case index is missing)
    private func startListeningFallback(userId: String) {
        listener = db.collection("ParkingTickets")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("❌ [TicketsViewModel] Fallback also failed: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let allTickets = documents.compactMap { try? $0.data(as: ParkingTicket.self) }
                    .sorted { $0.startTime > $1.startTime } // Sort locally
                
                self.activeTickets = allTickets.filter { $0.status == "active" || $0.status == "paid" }
                self.historyTickets = allTickets.filter { $0.status == "completed" }
                
                print("📊 [TicketsViewModel] Fallback - Active: \(self.activeTickets.count), History: \(self.historyTickets.count)")
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func formatDuration(start: Date, end: Date?) -> String {
        let endDate = end ?? Date()
        let diff = endDate.timeIntervalSince(start)
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        
        return "\(hours)h \(minutes)m"
    }
}
