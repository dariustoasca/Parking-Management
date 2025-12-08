import SwiftUI
import FirebaseFirestore
// import FirebaseFunctions
import Combine

// MARK: - Models
struct FloorStats: Identifiable {
    let id = UUID()
    let floor: Int
    let rooms: Int
    let occupied: Int
    let lightsOn: Int
    let avgTemp: Int
    let unlockedRooms: Int
}

struct RecentActivity: Identifiable, Decodable {
    let id: String
    let title: String
    let subtitle: String?
    let timestamp: String
    let category: String
    let icon: String
    let colorName: String
    let messageDirection: String?
    
    var color: Color {
        switch colorName {
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        default: return .gray
        }
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    
    @Published var isLoading = false
    
    // Stats
    @Published var activeSessions = 0
    @Published var lightsOn = 0
    @Published var availableParking = 0
    @Published var avgTemperature = 22
    @Published var unreadMessageCount = 0
    
    // Firestore
    private let db = Firestore.firestore(database: "parking")
    private var listeners: [ListenerRegistration] = []
    private var currentUserUID: String = ""
    
    deinit {
        listeners.forEach { $0.remove() }
    }
    
    func loadDashboardData(userUID: String) {
        self.currentUserUID = userUID
        startMessagesListener()
        // Add other listeners if needed for the profile stats
    }
    
    private func startMessagesListener() {
        guard !currentUserUID.isEmpty else { return }
        
        let listener = db.collection("Messages")
            .whereField("toUserIds", arrayContains: currentUserUID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                let unreadCount = documents.filter { doc in
                    let data = doc.data()
                    let readBy = data["readBy"] as? [String] ?? []
                    return !readBy.contains(self.currentUserUID)
                }.count
                
                self.unreadMessageCount = unreadCount
            }
        
        listeners.append(listener)
    }
}
