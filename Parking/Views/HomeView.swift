/*
 * HomeView.swift
 * Smart Parking System
 * Author: Darius Toasca
 * 
 * Main dashboard screen showing:
 * - Available parking spots count
 * - Current tariff information
 * - Active ticket status
 * - Enter/Exit parking buttons
 * 
 * The entry/exit flows work with physical Raspberry Pi buttons:
 * 1. User presses button in app
 * 2. Has 60 seconds to press physical barrier button
 * 3. Barrier opens and ticket is created/completed
 */

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

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
                    .padding(.bottom, 20)
                    
                    // Tariff Display
                    Text(ParkingPriceCalculator.tariffText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    // Enter Parking Button (only show if no active ticket)
                    if viewModel.canEnterParking || viewModel.isPendingEntry || viewModel.entrySuccess {
                        Button(action: {
                            HapticManager.impact(style: .medium)
                            viewModel.requestParkingEntry()
                        }) {
                            ZStack(alignment: .leading) {
                                // Frosted glass background
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                
                                // Progress fill (for countdown)
                                if viewModel.isPendingEntry {
                                    GeometryReader { geometry in
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.6), .blue.opacity(0.3)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(viewModel.entryRemainingTime) / 60.0)
                                            .animation(.linear(duration: 0.5), value: viewModel.entryRemainingTime)
                                    }
                                }
                                
                                // Success fill
                                if viewModel.entrySuccess {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green.opacity(0.6), .green.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                                
                                // Content
                                HStack {
                                    if viewModel.isPendingEntry {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    } else if viewModel.entrySuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "car.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        if viewModel.entrySuccess {
                                            Text("Entry Successful!")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("Barrier will open shortly")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if viewModel.isPendingEntry {
                                            Text("Waiting for Button...")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("\(viewModel.entryRemainingTime)s - Press barrier button")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Enter Parking")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("Tap to request entry")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if !viewModel.isPendingEntry && !viewModel.entrySuccess {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                            }
                            .frame(height: 70)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                        .disabled(viewModel.isPendingEntry || viewModel.entrySuccess)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    // Exit Barrier Button (show if recently paid OR pending exit OR barrier success)
                    if viewModel.canOpenBarrier || viewModel.isPendingExit || viewModel.barrierSuccess {
                        Button(action: {
                            HapticManager.impact(style: .medium)
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
                                
                                // Progress fill based on state
                                GeometryReader { geometry in
                                    if viewModel.isPendingExit {
                                        // Orange progress for waiting (60s countdown)
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.orange.opacity(0.6), .orange.opacity(0.3)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(viewModel.exitRemainingTime) / 60.0)
                                            .animation(.linear(duration: 0.5), value: viewModel.exitRemainingTime)
                                    } else if viewModel.barrierSuccess {
                                        // Blue fill for success
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.6), .blue.opacity(0.3)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    } else {
                                        // Green progress for 15-min window
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.green, .green.opacity(0.6)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(viewModel.remainingTime) / 15.0)
                                            .animation(.linear(duration: 0.5), value: viewModel.remainingTime)
                                    }
                                }
                                
                                // Content
                                HStack {
                                    if viewModel.barrierOpening {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    } else if viewModel.isPendingExit {
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
                                        if viewModel.barrierSuccess {
                                            Text("Barrier Opened!")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("Drive safely!")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if viewModel.isPendingExit {
                                            Text("Waiting for Button...")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("\(viewModel.exitRemainingTime)s - Press barrier button")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Open Exit Barrier")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text("\(viewModel.remainingTime) min remaining")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if !viewModel.barrierSuccess && !viewModel.barrierOpening && !viewModel.isPendingExit {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                            }
                            .frame(height: 70)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                        .disabled(viewModel.barrierOpening || viewModel.barrierSuccess || viewModel.isPendingExit)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    // Ticket Status
                    if let ticket = viewModel.activeTicket {
                        Button(action: { showTicketDetail = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active Ticket")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(formatSpotName(ticket.spotId))
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
                        .padding(.top, 30)
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
    
    private func formatSpotName(_ spotId: String) -> String {
        // Extract just the number from "spot1", "spot2", etc.
        if let number = spotId.last, number.isNumber {
            return String(number)
        }
        return spotId
    }
}
