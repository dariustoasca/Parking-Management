import Foundation
import FirebaseFirestore
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var availableSpotsCount: Int = 0
    @Published var activeTicket: ParkingTicket?
    @Published var userName: String = "User"
    
    private var db = Firestore.firestore(database: "parking")
    private var cancellables = Set<AnyCancellable>()
    private var spotsListener: ListenerRegistration?
    private var ticketListener: ListenerRegistration?
    
    init() {
        // Initial fetch or setup listeners
    }
    
    func startListening(userId: String) {
        listenToSpots()
        listenToActiveTicket(userId: userId)
        fetchUserName(userId: userId)
    }
    
    func stopListening() {
        spotsListener?.remove()
        ticketListener?.remove()
        spotsListener = nil
        ticketListener = nil
    }
    
    private func listenToSpots() {
        spotsListener = db.collection("ParkingSpots")
            .whereField("occupied", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to spots: \(error)")
                    return
                }
                
                if let snapshot = snapshot {
                    self.availableSpotsCount = snapshot.documents.count
                }
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
    
    private func fetchUserName(userId: String) {
        db.collection("Users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data(), let name = data["displayName"] as? String {
                self.userName = name
            }
        }
    }
}
