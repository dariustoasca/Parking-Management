import Foundation
import Combine
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let db = Firestore.firestore(database: "parking")
    private var messageListener: ListenerRegistration?
    @Published var hasNotificationPermission = false
    @Published var isDoNotDisturbEnabled = false
    
    override init() {
        super.init()
        checkNotificationPermission()
        setupMessageListener()
    }
    
    // MARK: - Permission Management
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasNotificationPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasNotificationPermission = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - Message Monitoring
    private func setupMessageListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        messageListener?.remove()
        messageListener = db.collection("Messages")
            .whereField("toUserIds", arrayContains: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                // Check for new messages
                snapshot?.documentChanges.forEach { change in
                    if change.type == .added {
                        let data = change.document.data()
                        
                        // Check if message is unread
                        let readBy = data["readBy"] as? [String] ?? []
                        if !readBy.contains(currentUserId) {
                            // Check if the message is recent (within last minute)
                            if let timestamp = data["timestamp"] as? Timestamp {
                                let messageDate = timestamp.dateValue()
                                let timeSinceMessage = Date().timeIntervalSince(messageDate)
                                
                                // Only notify for messages received in the last 60 seconds
                                if timeSinceMessage < 60 {
                                    self.sendNewMessageNotification(data: data, messageId: change.document.documentID, threadId: data["threadId"] as? String)
                                }
                            }
                        }
                    }
                    
                    // Update badge when messages change
                    if change.type == .modified {
                        self.updateBadgeCount()
                    }
                }
                
                // Always update badge count
                self.updateBadgeCount()
            }
    }
    
    // MARK: - Local Notifications
    private func sendNewMessageNotification(data: [String: Any], messageId: String, threadId: String?) {
        guard hasNotificationPermission && !isDoNotDisturbEnabled else { return }
        
        let content = UNMutableNotificationContent()
        
        // Get sender name
        let senderId = data["fromUserId"] as? String ?? ""
        let subject = data["subject"] as? String ?? "New Message"
        let body = data["body"] as? String ?? ""
        
        // Fetch sender's display name
        if !senderId.isEmpty {
            db.collection("Users").document(senderId).getDocument { [weak self] snapshot, _ in
                guard let self = self else { return }
                let senderName = snapshot?.data()?["displayName"] as? String ?? "Someone"
                
                content.title = senderName
                content.subtitle = subject
                content.body = String(body.prefix(100)) // Show first 100 chars
                content.sound = .default
                content.threadIdentifier = threadId ?? messageId
                content.userInfo = ["messageId": messageId, "threadId": threadId ?? messageId]
                
                // Update badge
                self.updateBadgeCount()
                
                // Create trigger (immediate)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                
                // Create request
                let request = UNNotificationRequest(
                    identifier: "message_\(messageId)",
                    content: content,
                    trigger: trigger
                )
                
                // Add notification
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error sending notification: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Badge Management
    func updateBadgeCount() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("Messages")
            .whereField("toUserIds", arrayContains: currentUserId)
            .getDocuments { snapshot, _ in
                let unreadCount = snapshot?.documents.filter { doc in
                    let readBy = doc.data()["readBy"] as? [String] ?? []
                    return !readBy.contains(currentUserId)
                }.count ?? 0
                
                DispatchQueue.main.async {
                    UNUserNotificationCenter.current().setBadgeCount(unreadCount)
                }
            }
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Parking Notifications
    func sendParkingAssignmentNotification(spotNumber: Int) {
        guard hasNotificationPermission && !isDoNotDisturbEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Parking Spot Assigned"
        content.body = "You've been assigned parking spot #\(spotNumber)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "parking_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Clock In/Out Reminders
    func scheduleClockInReminder() {
        guard hasNotificationPermission && !isDoNotDisturbEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Don't forget to clock in!"
        content.body = "Start your workday by clocking in through the app"
        content.sound = .default
        
        // Schedule for 9 AM on weekdays
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        dateComponents.weekday = 2 // Monday (1 is Sunday)
        
        for weekday in 2...6 { // Monday to Friday
            dateComponents.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "clockin_\(weekday)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func scheduleClockOutReminder() {
        guard hasNotificationPermission && !isDoNotDisturbEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to clock out!"
        content.body = "Don't forget to clock out before leaving"
        content.sound = .default
        
        // Schedule for 5 PM on weekdays
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 0
        
        for weekday in 2...6 { // Monday to Friday
            dateComponents.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "clockout_\(weekday)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    // MARK: - Temperature Alerts
    func sendTemperatureAlert(roomName: String, temperature: Int, isHigh: Bool) {
        guard hasNotificationPermission && !isDoNotDisturbEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = isHigh ? "High Temperature Alert" : "Low Temperature Alert"
        content.body = "\(roomName) temperature is \(temperature)°C"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "temp_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    deinit {
        messageListener?.remove()
    }
}

// MARK: - UNUserNotificationCenterDelegate Extension
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Don't show notification if DND is enabled
        if isDoNotDisturbEnabled {
            completionHandler([])
            return
        }
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        _ = response.notification.request.content.userInfo
        
        // Navigate to appropriate screen based on notification type
        if response.notification.request.identifier.hasPrefix("message_") {
            // Navigate to messages
            NotificationCenter.default.post(name: .navigateToMessages, object: nil)
        } else if response.notification.request.identifier.hasPrefix("parking_") {
            // Navigate to parking
            NotificationCenter.default.post(name: .navigateToParking, object: nil)
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToMessages = Notification.Name("navigateToMessages")
    static let navigateToParking = Notification.Name("navigateToParking")
    static let navigateToRooms = Notification.Name("navigateToRooms")
}
