import SwiftUI

struct ParkingGridView: View {
    @StateObject private var viewModel = ParkingGridViewModel()
    @State private var selectedSpot: ParkingSpot?
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    VStack(spacing: 20) {
                        Text("Select a parking spot")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.spots) { spot in
                                ParkingSpotCard(spot: spot, isSelected: selectedSpot?.id == spot.id)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedSpot = spot
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Parking Grid")
            .background(backgroundColor)
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground)
    }
}

struct ParkingSpotCard: View {
    let spot: ParkingSpot
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            Image(systemName: "car.fill")
                .font(.largeTitle)
                .foregroundColor(iconColor)
            
            Text("Spot \(spot.displayName)")
                .font(.headline)
                .foregroundColor(textColor)
            
            if spot.occupied {
                Text("Occupied")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.top, 2)
            } else {
                Text("Available")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.top, 2)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 2)
        )
    }
    
    private var iconColor: Color {
        if isSelected { return .white }
        return spot.occupied ? .gray : .blue
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        return .primary
    }
    
    private var cardBackground: Color {
        if isSelected { return .blue }
        return colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.17) : .white
    }
    
    private var borderColor: Color {
        if isSelected { return .blue }
        return .clear
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
}
