import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showTicketDetail = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                backgroundGradient
                
                VStack(spacing: 0) {
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
                    .padding(.top, 20)
                    
                    // Available Spots Circle
                    VStack(spacing: 30) {
                        ZStack {
                            // Background Circle
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                .frame(width: 220, height: 220)
                            
                            // Progress Circle
                            Circle()
                                .trim(from: 0, to: CGFloat(Double(viewModel.availableSpots) / Double(viewModel.totalSpots)))
                                .stroke(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 220, height: 220)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                                .animation(.easeOut, value: viewModel.availableSpots)
                            
                            VStack {
                                Text("\(viewModel.availableSpots)")
                                    .font(.system(size: 70, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("FREE SPOTS")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .tracking(2)
                            }
                        }
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                    
                    // Barrier Button (only show if recently paid)
                    if viewModel.canOpenBarrier {
                        Button(action: {
                            viewModel.openBarrier()
                        }) {
                            ZStack(alignment: .leading) {
                                // Frosted glass background
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                
                                // Green progress fill (decreases over time)
                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: viewModel.barrierSuccess ? [.blue, .blue.opacity(0.6)] : [.green, .green.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(viewModel.remainingTime) / 15.0)
                                        .animation(.linear(duration: 0.5), value: viewModel.remainingTime)
                                }
                                
                                // Content
                                HStack {
                                    if viewModel.barrierOpening {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    } else if viewModel.barrierSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "door.left.hand.open")
                                            .font(.title2)
                                            .foregroundColor(.green)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.barrierSuccess ? "Barrier Opened!" : "Open Exit Barrier")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        if viewModel.barrierSuccess {
                                            Text("Success - Drive safely!")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("\(viewModel.remainingTime) min remaining")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if !viewModel.barrierSuccess && !viewModel.barrierOpening {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                            }
                            .frame(height: 70)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                        .disabled(viewModel.barrierOpening || viewModel.barrierSuccess)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    // Barrier Success Message
                    if viewModel.barrierSuccess {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Barrier Successfully Opened!")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Barrier will remain open for 30 seconds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: viewModel.barrierSuccess)
                    }
                    
                    // Ticket Status
                    if let ticket = viewModel.activeTicket {
                        Button(action: { showTicketDetail = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active Ticket")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Spot \(ticket.spotId)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showTicketDetail, onDismiss: {
                            // Refresh listener when returning from ticket detail
                            if let userId = authManager.currentUserUID {
                                viewModel.startListening(userId: userId)
                            }
                        }) {
                            if let ticketId = ticket.id {
                                TicketDetailView(ticketId: ticketId)
                            }
                        }
                    } else {
                        // No active ticket - just text, no background
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No active parking tickets")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, (viewModel.canOpenBarrier || viewModel.barrierSuccess) ? 40 : 0)
                    }
                    
                    Spacer()
                }
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
    
    private var backgroundGradient: some View {
        BackgroundView()
    }
}
