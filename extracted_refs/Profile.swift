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
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled: Bool = false
    
    @State private var showSignOutAlert = false
    @State private var showResetPasswordAlert = false
    @State private var didSendResetEmail: Bool = false
    @State private var showGradientPicker = false
    
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
                        quickStatsSection
                        
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
        .onAppear {
            if let userId = authManager.currentUserUID {
                profilePicManager.startListeningToProfile(userId: userId)
            }
        }
        .onDisappear {
            profilePicManager.stopListening()
        }
    }
    
    // MARK: - Background
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
        .background(cardBackground)
        .cornerRadius(20)
        .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        QuickStatsView()
            .environmentObject(authManager)
            .environmentObject(dashboardVM)
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Face ID Toggle
                SettingsToggleRow(
                    icon: "faceid",
                    title: BiometricAuthManager.biometricTypeString(),
                    color: .blue,
                    isOn: Binding(
                        get: { isFaceIDEnabled },
                        set: { newValue in
                            isFaceIDEnabled = newValue
                            Task {
                                if newValue {
                                    try? await authManager.enableFaceID()
                                } else {
                                    try? await authManager.disableFaceID()
                                }
                            }
                        }
                    )
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
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
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
        let db = Firestore.firestore()
        
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
                .onChange(of: isOn) { _ in
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
                        
                        Text("HQ Management")
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
                        
                        Text("HQ Management is a comprehensive smart office management system designed to streamline workplace operations. Manage rooms, parking, time tracking, and internal communications all in one place.")
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
                        
                        FeatureRow(icon: "building.2.fill", title: "Room Management", description: "Control lights, HVAC, and monitor occupancy")
                        Divider()
                        FeatureRow(icon: "parkingsign", title: "Parking Management", description: "Assign and track parking spots")
                        Divider()
                        FeatureRow(icon: "clock.fill", title: "Time Tracking", description: "Clock in/out and track work hours")
                        Divider()
                        FeatureRow(icon: "envelope.fill", title: "Messaging", description: "Internal communication system")
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
                                
                                Text("D")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Darius Toasca")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                
                                Text("Software Developer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
                    
                    // Copyright
                    Text("© 2025 HQ Management. All rights reserved.")
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

// MARK: - Profile Picture Manager
class ProfilePictureManager: ObservableObject {
    @Published var profileImage: UIImage?
    @Published var backgroundColor: String = "blue"
    
    static let shared = ProfilePictureManager()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
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
        listener = nil
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
