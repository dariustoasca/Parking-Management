//
//  ProfilePictureManager.swift
//  HQManagement
//
//  Created by Darius Toasca on 18.11.2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

class ProfilePictureManager: ObservableObject {
    @Published var profileImage: UIImage?
    @Published var backgroundColor: String = "blue"
    
    static let shared = ProfilePictureManager()
    private let db = Firestore.firestore(database: "parking")
    
    // 8 predefined gradient options
    let gradientOptions: [(name: String, colors: [Color])] = [
        ("blue", [Color.blue, Color.blue.opacity(0.7)]),
        ("purple", [Color.purple, Color.purple.opacity(0.7)]),
        ("pink", [Color.pink, Color.pink.opacity(0.7)]),
        ("orange", [Color.orange, Color.orange.opacity(0.7)]),
        ("green", [Color.green, Color.green.opacity(0.7)]),
        ("teal", [Color.teal, Color.teal.opacity(0.7)]),
        ("indigo", [Color.indigo, Color.indigo.opacity(0.7)]),
        ("red", [Color.red, Color.red.opacity(0.7)])
    ]
    
    private var listener: ListenerRegistration?

    func startListeningToProfile(userId: String) {
        listener?.remove()
        listener = db.collection("Users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self?.backgroundColor = data["profileBackgroundColor"] as? String ?? "blue"
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
    }

    func loadUserProfile(userId: String) {
        db.collection("Users").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data() else { return }
            
            DispatchQueue.main.async {
                self?.backgroundColor = data["profileBackgroundColor"] as? String ?? "blue"
            }
        }
    }
    
    func updateBackgroundColor(color: String, userId: String, completion: @escaping (Bool) -> Void) {
        db.collection("Users").document(userId).updateData([
            "profileBackgroundColor": color
        ]) { error in
            DispatchQueue.main.async {
                if error == nil {
                    self.backgroundColor = color
                    NotificationCenter.default.post(name: NSNotification.Name("ProfileColorChanged"), object: nil)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    func getColorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        case "red": return .red
        default: return .blue
        }
    }
    
    func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1))
            let lastInitial = String(components[1].prefix(1))
            return (firstInitial + lastInitial).uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "U"
    }
}
