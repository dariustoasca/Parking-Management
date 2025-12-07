import SwiftUI

struct TicketsView: View {
    @State private var selectedTicket: TicketItem?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Active Ticket")) {
                    TicketRow(id: "TKT-2025-001", status: "Active", time: "2h 15m", color: .green)
                        .onTapGesture {
                            selectedTicket = TicketItem(id: "TKT-2025-001")
                        }
                }
                
                Section(header: Text("History")) {
                    TicketRow(id: "TKT-2024-892", status: "Paid", time: "4h 30m", color: .gray)
                    TicketRow(id: "TKT-2024-855", status: "Paid", time: "1h 45m", color: .gray)
                    TicketRow(id: "TKT-2024-810", status: "Paid", time: "8h 00m", color: .gray)
                }
            }
            .navigationTitle("My Tickets")
            .sheet(item: $selectedTicket) { item in
                TicketDetailView(ticketId: item.id)
            }
        }
    }
}

struct TicketItem: Identifiable {
    let id: String
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
        .contentShape(Rectangle()) // Make whole row tappable
    }
}
