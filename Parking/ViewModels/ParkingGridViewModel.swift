import Foundation
import FirebaseFirestore
import Combine

@MainActor
class ParkingGridViewModel: ObservableObject {
    @Published var spots: [ParkingSpot] = []
    @Published var isLoading = true
    
    private var db = Firestore.firestore(database: "parking")
    private var listener: ListenerRegistration?
    
    func startListening() {
        isLoading = true
        listener = db.collection("ParkingSpots")
            .order(by: "number")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching spots: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    self.spots = documents.compactMap { doc in
                        try? doc.data(as: ParkingSpot.self)
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
