import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Profile Picture Manager Instance


struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @ObservedObject var profilePicManager = ProfilePictureManager.shared
    private let notificationManager = NotificationManager.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    // FaceID AppStorage removed
    
    @State private var showSignOutAlert = false
    @State private var showResetPasswordAlert = false
    @State private var didSendResetEmail: Bool = false
    @State private var showGradientPicker = false
    @State private var showUsernameSheet = false
    @State private var showPaymentMethodsSheet = false
    @State private var lightsOn = false
    @State private var lightsListener: ListenerRegistration?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        profileHeader
                        
                        // Quick Stats
                        // quickStatsSection // Removed
                        
                        // Settings
                        settingsSection
                        
                        // Sign Out Button
                        signOutButton
                    }
                    .padding()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: colorScheme)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Reset Password", isPresented: $showResetPasswordAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Send Email") {
                if let email = authManager.currentUserEmail {
                    Task {
                        try? await authManager.sendPasswordResetEmail(email: email)
                    }
                }
                didSendResetEmail = true
            }
        } message: {
            Text("A password reset link will be sent to your email address.")
        }
        .alert("Email Sent", isPresented: $didSendResetEmail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password reset email has been sent successfully.")
        }
        .sheet(isPresented: $showGradientPicker) {
            GradientPickerSheet(viewModel: authManager, onDismiss: { showGradientPicker = false })
        }
        .sheet(isPresented: $showUsernameSheet) {
            UsernameChangeSheet(authManager: authManager, isPresented: $showUsernameSheet)
        }
        .sheet(isPresented: $showPaymentMethodsSheet) {
            PaymentMethodsView(isPresented: $showPaymentMethodsSheet)
        }
        .onAppear {
            if let userId = authManager.currentUserUID {
                profilePicManager.startListeningToProfile(userId: userId)
            }
            startListeningToLights()
        }
        .onDisappear {
            profilePicManager.stopListening()
            lightsListener?.remove()
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        BackgroundView()
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar with gradient
            Button(action: { showGradientPicker = true }) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        profilePicManager.getColorFromName(profilePicManager.backgroundColor),
                                        profilePicManager.getColorFromName(profilePicManager.backgroundColor).opacity(0.7)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Text(profilePicManager.getInitials(from: authManager.currentUserData?["displayName"] as? String ?? "User"))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Edit icon
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.blue).frame(width: 30, height: 30))
                        .offset(x: 5, y: 5)
                }
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            
            // Name & Role
            VStack(spacing: 8) {
                Text(authManager.currentUserData?["displayName"] as? String ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(authManager.currentUserEmail ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let role = authManager.currentUserData?["role"] as? String {
                    RoleBadgeView(role: role)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Quick Stats
    // Removed
    /*
    private var quickStatsSection: some View {
        QuickStatsView()
            .environmentObject(authManager)
            .environmentObject(dashboardVM)
    }
    */
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Face ID Toggle Removed
                
                // Parking Lights Toggle
                SettingsToggleRow(
                    icon: "lightbulb.fill",
                    title: "Parking Lights",
                    color: lightsOn ? .yellow : .gray,
                    isOn: Binding(
                        get: { lightsOn },
                        set: { newValue in
                            toggleParkingLights(newValue)
                        }
                    )
                )
                
                Divider().padding(.leading, 56)
                
                // Change Username
                SettingsButtonRow(
                    icon: "person.fill",
                    title: "Change Username",
                    color: .blue,
                    action: {
                        HapticManager.selection()
                        showUsernameSheet = true
                    }
                )
                
                Divider().padding(.leading, 56)
                
                // Payment Methods
                SettingsButtonRow(
                    icon: "creditcard.fill",
                    title: "Payment Methods",
                    color: .green,
                    action: {
                        HapticManager.selection()
                        showPaymentMethodsSheet = true
                    }
                )
                
                Divider().padding(.leading, 56)
                
                // Dark Mode Toggle
                SettingsToggleRow(
                    icon: "moon.fill",
                    title: "Dark Mode",
                    color: .purple,
                    isOn: $isDarkMode
                )
                
                Divider().padding(.leading, 56)
                
                // Notifications with permission check
                SettingsButtonRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    color: .red,
                    action: {
                        HapticManager.selection()
                        if !notificationManager.hasNotificationPermission {
                            notificationManager.requestNotificationPermission()
                        } else {
                            // Show notification settings
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                )
                
                Divider().padding(.leading, 56)
                
                // Change Password
                SettingsButtonRow(
                    icon: "lock.fill",
                    title: "Change Password",
                    color: .orange,
                    action: {
                        HapticManager.selection()
                        showResetPasswordAlert = true
                    }
                )
                
                Divider().padding(.leading, 56)
                
                // About
                NavigationLink(destination: AboutView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .frame(width: 32)
                        
                        Text("About")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 6)
        }
    }
    
    // MARK: - Sign Out Button
    private var signOutButton: some View {
        Button(action: { 
            HapticManager.impact(style: .medium)
            showSignOutAlert = true 
        }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title3)
                Text("Sign Out")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    private var avatarGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue, Color.purple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.13)
            } else {
                Color(.systemBackground)
            }
        }
    }
    
    // MARK: - Parking Lights Functions
    private func startListeningToLights() {
        let db = Firestore.firestore(database: "parking")
        lightsListener = db.collection("Parking").document("SystemSettings")
            .addSnapshotListener { snapshot, error in
                if let data = snapshot?.data(),
                   let isOn = data["lightsOn"] as? Bool {
                    lightsOn = isOn
                }
            }
    }
    
    private func toggleParkingLights(_ newValue: Bool) {
        HapticManager.impact(style: .light)
        let db = Firestore.firestore(database: "parking")
        db.collection("Parking").document("SystemSettings").updateData([
            "lightsOn": newValue,
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error toggling lights: \(error)")
            }
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.2)
    }
}

// MARK: - Role Badge View
struct RoleBadgeView: View {
    let role: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: roleIcon)
                .font(.caption)
            Text(role)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundColor(roleColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(roleColor.opacity(0.15))
        .cornerRadius(20)
    }
    
    private var roleIcon: String {
        switch role {
        case "CEO": return "star.fill"
        case "Admin": return "shield.fill"
        case "HR": return "person.2.fill"
        case "Manager": return "briefcase.fill"
        default: return "person.fill"
        }
    }
    
    private var roleColor: Color {
        switch role {
        case "CEO": return .purple
        case "Admin": return .orange
        case "HR": return .green
        case "Manager": return .blue
        default: return .gray
        }
    }
}

// MARK: - Quick Stats View
struct QuickStatsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @State private var totalHours: Double = 0
    @State private var parkingSpot: String = "None"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ProfileStatCard(
                    title: "Hours",
                    value: String(format: "%.1fh", totalHours),
                    icon: "clock.fill",
                    color: .green
                )
                
                ProfileStatCard(
                    title: "Messages",
                    value: "\(dashboardVM.unreadMessageCount)",
                    icon: "envelope.fill",
                    color: .blue
                )
                
                ProfileStatCard(
                    title: "Parking",
                    value: parkingSpot,
                    icon: "parkingsign",
                    color: .orange
                )
            }
        }
        .onAppear {
            loadQuickStats()
        }
    }
    
    private func loadQuickStats() {
        guard let userId = authManager.currentUserUID else { return }
        let db = Firestore.firestore(database: "parking")
        
        // Load total hours from time tracking
        db.collection("TimeTracking")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "completed")
            .getDocuments { snapshot, _ in
                let hours = snapshot?.documents.reduce(0.0) { sum, doc in
                    let totalHours = doc.data()["totalHours"] as? Double ?? 0
                    return sum + totalHours
                } ?? 0
                
                DispatchQueue.main.async {
                    self.totalHours = hours
                }
            }
        
        // Load parking spot
        db.collection("Parking")
            .whereField("assignedUserId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let spot = snapshot?.documents.first {
                    let data = spot.data()
                    let number = data["number"] as? Int ?? 0
                    let section = data["section"] as? String ?? ""
                    
                    DispatchQueue.main.async {
                        self.parkingSpot = "\(section)-\(number)"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parkingSpot = "None"
                    }
                }
            }
    }
}

// MARK: - Profile Stat Card
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
    }
    
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.13)
            } else {
                Color(.systemBackground)
            }
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.2)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { 
                    HapticManager.selection()
                }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Button Row
// MARK: - About View
struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Parking Management")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Parking Management is a smart system designed to simplify parking operations. View available spots, pay for tickets, and control barriers seamlessly. This app integrates with a physical maquette powered by Arduino and Raspberry Pi for real-time hardware control.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        FeatureRow(icon: "parkingsign", title: "Real-time Availability", description: "Monitor parking spot status instantly")
                        Divider()
                        FeatureRow(icon: "ticket.fill", title: "Ticket Management", description: "View and pay for parking tickets")
                        Divider()
                        FeatureRow(icon: "sensor.tag.radiowaves.forward.fill", title: "Hardware Integration", description: "Control barriers via Arduino & RPi")
                        Divider()
                        FeatureRow(icon: "bell.fill", title: "Smart Notifications", description: "Stay updated with real-time alerts")
                    }
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Developed By")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "person.3.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Darius Toasca")
                                Text("Szilagyi Dragos")
                                Text("Cereteu Paul")
                                Text("Sava Mihnea")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
                    
                    // Copyright
                    Text("© 2025 Parking Management. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
                .padding()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.3),
                Color(red: 29/255, green: 78/255, blue: 216/255).opacity(0.2),
                Color(red: 49/255, green: 46/255, blue: 129/255).opacity(0.4)
            ]
        } else {
            return [
                Color(red: 240/255, green: 242/255, blue: 246/255),
                Color(red: 226/255, green: 232/255, blue: 240/255),
                Color(red: 203/255, green: 213/255, blue: 225/255)
            ]
        }
    }
    
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.13)
            } else {
                Color(.systemBackground)
            }
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.2)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Gradient Picker Sheet
struct GradientPickerSheet: View {
    @ObservedObject var viewModel: AuthenticationManager
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var picManager = ProfilePictureManager.shared
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        VStack(spacing: 8) {
                            Text("Choose Your Profile Color")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Select a color gradient for your profile")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top)
                        
                        // Gradient Options Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(gradientOptions, id: \.name) { option in
                                Button {
                                    selectGradient(option.name)
                                } label: {
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: option.colors),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 80, height: 80)
                                            
                                            Text(picManager.getInitials(from: viewModel.currentUserData?["displayName"] as? String ?? "User"))
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            // Selected checkmark
                                            if picManager.backgroundColor == option.name {
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 3)
                                                    .frame(width: 85, height: 85)
                                                
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.green).frame(width: 26, height: 26))
                                                    .offset(x: 32, y: -32)
                                            }
                                        }
                                        
                                        Text(option.name.capitalized)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                    .background(cardBackground)
                                    .cornerRadius(16)
                                    .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Profile Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func selectGradient(_ colorName: String) {
        guard let userId = viewModel.currentUserUID else { return }
        
        picManager.updateBackgroundColor(color: colorName, userId: userId) { success in
            if success {
                HapticManager.notification(type: .success)
            }
        }
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.3),
                Color(red: 29/255, green: 78/255, blue: 216/255).opacity(0.2),
                Color(red: 49/255, green: 46/255, blue: 129/255).opacity(0.4)
            ]
        } else {
            return [
                Color(red: 240/255, green: 242/255, blue: 246/255),
                Color(red: 226/255, green: 232/255, blue: 240/255),
                Color(red: 203/255, green: 213/255, blue: 225/255)
            ]
        }
    }
    
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.13)
            } else {
                Color(.systemBackground)
            }
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.2)
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Username Change Sheet

struct UsernameChangeSheet: View {
    @ObservedObject var authManager: AuthenticationManager
    @Binding var isPresented: Bool
    @State private var newUsername: String = ""
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Change Username")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your new display name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Current Username
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                        
                        Text(authManager.currentUserData?["displayName"] as? String ?? "User")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // New Username Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                        
                        TextField("Enter new username", text: $newUsername)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Update Button
                Button(action: updateUsername) {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Update Username")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newUsername.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(newUsername.trimmingCharacters(in: .whitespaces).isEmpty || isUpdating)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            newUsername = authManager.currentUserData?["displayName"] as? String ?? ""
        }
    }
    
    private func updateUsername() {
        let trimmedName = newUsername.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else { return }
        
        isUpdating = true
        
        Task {
            do {
                try await authManager.updateDisplayName(name: trimmedName)
                await MainActor.run {
                    isUpdating = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Payment Methods View
struct PaymentMethodsView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var savedCards: [PaymentCard] = []
    @State private var isLoading = true
    @State private var showAddCardForm = false
    
    // New card form fields
    @State private var cardNumber = ""
    @State private var expirationDate = ""
    @State private var cvv = ""
    @State private var cardHolderName = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let db = Firestore.firestore(database: "parking")
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        } else if savedCards.isEmpty && !showAddCardForm {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("No Payment Methods")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Add a credit card to save time when paying for tickets")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: { showAddCardForm = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Card")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.top, 50)
                        } else {
                            // Saved Cards List
                            if !savedCards.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Your Cards")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    ForEach(savedCards) { card in
                                        PaymentCardRow(card: card, onDelete: {
                                            deleteCard(card)
                                        })
                                    }
                                }
                                .padding()
                                .background(cardBackground)
                                .cornerRadius(16)
                            }
                            
                            // Add Card Form
                            if showAddCardForm {
                                addCardFormSection
                            } else {
                                Button(action: { showAddCardForm = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add New Card")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(cardBackground)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Payment Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Payment Method"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                loadSavedCards()
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.3),
                Color(red: 29/255, green: 78/255, blue: 216/255).opacity(0.2),
                Color(red: 49/255, green: 46/255, blue: 129/255).opacity(0.4)
            ]
        } else {
            return [
                Color(red: 240/255, green: 242/255, blue: 246/255),
                Color(red: 226/255, green: 232/255, blue: 240/255),
                Color(red: 203/255, green: 213/255, blue: 225/255)
            ]
        }
    }
    
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.13)
            } else {
                Color(.systemBackground)
            }
        }
    }
    
    private var addCardFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add New Card")
                    .font(.headline)
                Spacer()
                Button(action: { showAddCardForm = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 16) {
                // Card Number
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0000 0000 0000 0000", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .onChange(of: cardNumber) { _, newValue in
                            if newValue.count > 16 {
                                cardNumber = String(newValue.prefix(16))
                            }
                        }
                }
                
                HStack(spacing: 16) {
                    // Expiration
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expires (MM/YY)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("MM/YY", text: $expirationDate)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: expirationDate) { _, newValue in
                                // Auto-format with /
                                var cleaned = newValue.filter { $0.isNumber }
                                if cleaned.count > 4 {
                                    cleaned = String(cleaned.prefix(4))
                                }
                                if cleaned.count >= 2 {
                                    let month = String(cleaned.prefix(2))
                                    let year = String(cleaned.dropFirst(2))
                                    expirationDate = month + "/" + year
                                } else {
                                    expirationDate = cleaned
                                }
                            }
                    }
                    
                    // CVV
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("123", text: $cvv)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: cvv) { _, newValue in
                                if newValue.count > 3 {
                                    cvv = String(newValue.prefix(3))
                                }
                            }
                    }
                }
                
                // Cardholder Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cardholder Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("John Doe", text: $cardHolderName)
                        .autocapitalization(.words)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Save Button
                Button(action: saveCard) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Card")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!isFormValid || isSaving)
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private var isFormValid: Bool {
        cardNumber.count == 16 &&
        expirationDate.count >= 4 &&
        cvv.count == 3 &&
        !cardHolderName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func loadSavedCards() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        db.collection("Users").document(userId).collection("CreditCardDetails")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                isLoading = false
                if let error = error {
                    print("❌ Error loading cards: \(error.localizedDescription)")
                    return
                }
                
                savedCards = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: PaymentCard.self)
                } ?? []
            }
    }
    
    private func saveCard() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isSaving = true
        
        let last4 = String(cardNumber.suffix(4))
        let cardType = detectCardType(cardNumber: cardNumber)
        let expComponents = expirationDate.replacingOccurrences(of: "/", with: "")
        
        let expiryMonth = expComponents.count >= 2 ? String(expComponents.prefix(2)) : ""
        let expiryYear = expComponents.count >= 4 ? String(expComponents.suffix(2)) : ""
        
        let cardData: [String: Any] = [
            "userId": userId,
            "last4Digits": last4,
            "cardType": cardType,
            "cardHolderName": cardHolderName.trimmingCharacters(in: .whitespaces),
            "expiryMonth": expiryMonth,
            "expiryYear": expiryYear,
            "isDefault": savedCards.isEmpty,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("Users").document(userId).collection("CreditCardDetails").addDocument(data: cardData) { error in
            isSaving = false
            
            if let error = error {
                alertMessage = "Failed to save card: \(error.localizedDescription)"
                showAlert = true
            } else {
                // Clear form and reload
                cardNumber = ""
                expirationDate = ""
                cvv = ""
                cardHolderName = ""
                showAddCardForm = false
                alertMessage = "Card saved successfully!"
                showAlert = true
                loadSavedCards()
            }
        }
    }
    
    private func deleteCard(_ card: PaymentCard) {
        guard let userId = Auth.auth().currentUser?.uid,
              let cardId = card.id else { return }
        
        // Remove from local array
        if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
            savedCards.remove(at: index)
        }
        
        // Delete from Firestore
        db.collection("Users").document(userId).collection("CreditCardDetails").document(cardId).delete { error in
            if let error = error {
                print("❌ Error deleting card: \(error.localizedDescription)")
                loadSavedCards() // Reload on error
            }
        }
    }
    
    private func detectCardType(cardNumber: String) -> String {
        let firstDigit = cardNumber.prefix(1)
        let firstTwo = cardNumber.prefix(2)
        
        if firstDigit == "4" {
            return "Visa"
        } else if ["51", "52", "53", "54", "55"].contains(firstTwo) {
            return "Mastercard"
        } else if ["34", "37"].contains(firstTwo) {
            return "Amex"
        } else if firstTwo == "65" || cardNumber.hasPrefix("6011") {
            return "Discover"
        }
        return "Card"
    }
}

// MARK: - Payment Card Row (for Profile)
struct PaymentCardRow: View {
    let card: PaymentCard
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cardIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Expires \(card.expiryDisplay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if card.isDefault {
                Text("Default")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding()
        .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var cardIcon: String {
        switch card.cardType.lowercased() {
        case "visa": return "creditcard.fill"
        case "mastercard": return "creditcard.circle.fill"
        case "amex": return "creditcard.trianglebadge.exclamationmark"
        default: return "creditcard"
        }
    }
}

// MARK: - Profile Picture Manager

