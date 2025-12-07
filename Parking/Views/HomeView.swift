import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showTicketDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header with Greeting
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello,")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(viewModel.userName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Active Ticket Card (if exists)
                if let ticket = viewModel.activeTicket {
                    Button(action: { showTicketDetail = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "ticket.fill")
                                        .foregroundColor(.white)
                                    Text("Active Ticket")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Text("Spot \(ticket.spotId)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Tap to view & pay")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showTicketDetail) {
                        if let ticketId = ticket.id {
                            TicketDetailView(ticketId: ticketId)
                        }
                    }
                }
                
                Spacer()
                
                // Available Spots Circle
                VStack(spacing: 16) {
                    Text("Available Spots")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 20
                            )
                            .frame(width: 220, height: 220)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        VStack {
                            Text("\(viewModel.availableSpotsCount)")
                                .font(.system(size: 70, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("OPEN")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .tracking(2)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                if let userId = authManager.currentUserUID {
                    viewModel.startListening(userId: userId)
                }
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }
}
