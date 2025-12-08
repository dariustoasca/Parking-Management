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
        
        listener = db.collection("ParkingTickets")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching tickets: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let allTickets = documents.compactMap { try? $0.data(as: ParkingTicket.self) }
                
                self.activeTickets = allTickets.filter { $0.status == "active" || $0.status == "paid" }
                self.historyTickets = allTickets.filter { $0.status == "completed" }
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
