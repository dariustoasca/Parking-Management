import SwiftUI

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
                    List {
                        if !viewModel.activeTickets.isEmpty {
                            Section(header: Text("Active Ticket")) {
                                ForEach(viewModel.activeTickets) { ticket in
                                    TicketRow(
                                        id: ticket.id ?? "Unknown",
                                        status: ticket.status.capitalized,
                                        time: viewModel.formatDuration(start: ticket.startTime, end: nil),
                                        color: ticket.status == "paid" ? .green : .blue
                                    )
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
                                        color: .gray
                                    )
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(id)
                    .font(.headline)
                    .monospaced()
                Text(time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
