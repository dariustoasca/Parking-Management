import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var dashboardVM = DashboardViewModel()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                TabView {
                    HomeView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                    
                    ParkingGridView()
                        .tabItem {
                            Label("Grid", systemImage: "square.grid.2x2.fill")
                        }
                    
                    TicketsView()
                        .tabItem {
                            Label("Tickets", systemImage: "ticket.fill")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle.fill")
                        }
                }
                .accentColor(.blue)
                .environmentObject(authManager)
                .environmentObject(dashboardVM)
                .onChange(of: authManager.isAuthenticated) { _, isAuth in
                    if isAuth, let uid = authManager.currentUserUID {
                        dashboardVM.loadDashboardData(userUID: uid)
                    }
                }
                .onAppear {
                    if let uid = authManager.currentUserUID {
                        dashboardVM.loadDashboardData(userUID: uid)
                    }
                }
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
