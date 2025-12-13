import SwiftUI

struct ParkingGridView: View {
    @StateObject private var viewModel = ParkingGridViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with subtle gradient
                BackgroundView()
                
                ScrollView(showsIndicators: false) {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.spots.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 24) {
                            // Header stats card
                            statsCard
                            
                            // Custom layout for 5 spots
                            spotsGrid
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Parking")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            Text("Loading spots...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "parkingsign.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Parking Spots")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please seed the database first")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 100)
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        let availableCount = viewModel.spots.filter { !$0.occupied }.count
        let occupiedCount = viewModel.spots.filter { $0.occupied }.count
        
        return HStack(spacing: 0) {
            StatItem(
                icon: "checkmark.circle.fill",
                value: "\(availableCount)",
                label: "Available",
                color: .green
            )
            
            Divider()
                .frame(height: 40)
                .padding(.horizontal, 16)
            
            StatItem(
                icon: "xmark.circle.fill",
                value: "\(occupiedCount)",
                label: "Occupied",
                color: .red
            )
            
            Divider()
                .frame(height: 40)
                .padding(.horizontal, 16)
            
            StatItem(
                icon: "square.grid.2x2.fill",
                value: "\(viewModel.spots.count)",
                label: "Total",
                color: .blue
            )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Spots Grid (5 spots: 2-2-1 layout)
    private var spotsGrid: some View {
        let spots = viewModel.spots.sorted { $0.number < $1.number }
        
        return VStack(spacing: 16) {
            // Row 1: Spots 1 & 2
            if spots.count >= 2 {
                HStack(spacing: 16) {
                    LiquidGlassSpotCard(spot: spots[0])
                    LiquidGlassSpotCard(spot: spots[1])
                }
            }
            
            // Row 2: Spots 3 & 4
            if spots.count >= 4 {
                HStack(spacing: 16) {
                    LiquidGlassSpotCard(spot: spots[2])
                    LiquidGlassSpotCard(spot: spots[3])
                }
            }
            
            // Row 3: Spot 5 (centered)
            if spots.count >= 5 {
                HStack {
                    Spacer()
                    LiquidGlassSpotCard(spot: spots[4])
                        .frame(maxWidth: UIScreen.main.bounds.width / 2 - 24)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Liquid Glass Spot Card
struct LiquidGlassSpotCard: View {
    let spot: ParkingSpot
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    private var statusColor: Color {
        spot.occupied ? .red : .green
    }
    
    private var statusGradient: LinearGradient {
        LinearGradient(
            colors: spot.occupied
                ? [Color.red.opacity(0.8), Color.orange.opacity(0.6)]
                : [Color.green.opacity(0.8), Color.teal.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator orb
            ZStack {
                // Outer glow
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .blur(radius: 8)
                
                // Glass orb
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: statusColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Icon
                Image(systemName: spot.occupied ? "car.fill" : "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(statusGradient)
            }
            
            // Spot info
            VStack(spacing: 4) {
                Text(spot.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(spot.occupied ? "Occupied" : "Available")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                statusColor.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Border highlight
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.6),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 16, x: 0, y: 8)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            withAnimation {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
            HapticManager.selection()
        }
    }
}
