import SwiftUI

struct ParkingGridView: View {
    @StateObject private var viewModel = ParkingGridViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView()
                
                ScrollView {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if viewModel.spots.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "parkingsign.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No parking spots available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Please seed the database first")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 100)
                    } else {
                        VStack(spacing: 20) {

                            
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.spots) { spot in
                                    ParkingSpotCard(spot: spot)
                                }
                            }
                            .padding()
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Parking Grid")
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }
}

struct ParkingSpotCard: View {
    let spot: ParkingSpot
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
            
            Text(spot.displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(spot.occupied ? "Occupied" : "Available")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: spot.occupied ? 
                    [Color.red.opacity(0.8), Color.red] : 
                    [Color.green.opacity(0.8), Color.green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
    }
    
    private var shadowColor: Color {
        if spot.occupied {
            return Color.red.opacity(0.3)
        } else {
            return Color.green.opacity(0.3)
        }
    }
}
