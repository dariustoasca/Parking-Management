/*
 * TicketsView.swift
 * Smart Parking System
 * Author: Darius Toasca
 * 
 * Displays the user's parking ticket history.
 * Shows both active tickets and completed/paid tickets in separate sections.
 * Prices are calculated dynamically using ParkingPriceCalculator.
 */

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TicketsView: View {
    @StateObject private var viewModel = TicketsViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTicket: ParkingTicket?
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.activeTickets.isEmpty && viewModel.historyTickets.isEmpty {
                    ProgressView()
                } else {
                    // TimelineView for real-time price updates every 30 seconds
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        List {
                            if !viewModel.activeTickets.isEmpty {
                                Section(header: Text("Active Ticket")) {
                                    ForEach(viewModel.activeTickets) { ticket in
                                        TicketRow(
                                            id: ticket.id ?? "Unknown",
                                            status: ticket.status.capitalized,
                                            time: viewModel.formatDuration(start: ticket.startTime, end: nil),
                                            color: ticket.status == "active" ? .green : .blue,
                                            amount: ParkingPriceCalculator.calculatePrice(from: ticket.startTime),
                                            currentTime: context.date  // Force recalculation
                                        )
                                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                        .onTapGesture {
                                            selectedTicket = ticket
                                        }
                                    }
                                }
                            }
                            
                            if !viewModel.historyTickets.isEmpty {
                                Section(header: Text("History")) {
                                    ForEach(viewModel.historyTickets) { ticket in
                                        TicketRow(
                                            id: ticket.id ?? "Unknown",
                                            status: ticket.status.capitalized,
                                            time: viewModel.formatDuration(start: ticket.startTime, end: ticket.endTime),
                                            color: .gray,
                                            amount: ParkingPriceCalculator.calculatePrice(from: ticket.startTime, to: ticket.endTime ?? Date()),
                                            currentTime: context.date
                                        )
                                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                        .onTapGesture {
                                            selectedTicket = ticket
                                        }
                                    }
                                }
                            }
                            
                            if viewModel.activeTickets.isEmpty && viewModel.historyTickets.isEmpty {
                                Text("No tickets found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("My Tickets")
            .sheet(item: $selectedTicket) { ticket in
                if let ticketId = ticket.id {
                    TicketDetailView(ticketId: ticketId)
                }
            }
            .background(BackgroundView())
            .scrollContentBackground(.hidden)
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

struct TicketRow: View {
    let id: String
    let status: String
    let time: String
    let color: Color
    let amount: Double
    var currentTime: Date = Date()  // Used to trigger refresh from TimelineView
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(id)
                    .font(.headline)
                    .monospaced()
                HStack(spacing: 8) {
                    Text(time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(ParkingPriceCalculator.formatPrice(amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(8)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(colorScheme == .dark ? 0.06 : 0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
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
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
    }
}
