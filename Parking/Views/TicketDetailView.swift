import SwiftUI
import FirebaseFirestore
import CoreImage.CIFilterBuiltins

struct TicketDetailView: View {
    let ticketId: String
    @Environment(\.dismiss) var dismiss
    @State private var ticket: ParkingTicket?
    @State private var isLoading = true
    @State private var showPayView = false
    @State private var showingBarrierAlert = false
    @State private var barrierMessage = ""
    @State private var barrierOpening = false
    @State private var barrierSuccess = false
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let ticket = ticket {
                    VStack(spacing: 30) {
                        // Ticket Header
                        VStack(spacing: 8) {
                            Text("Parking Ticket")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(ticketId)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospaced()
                            
                            Text(ticket.status.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(statusColor(ticket.status).opacity(0.1))
                                .foregroundColor(statusColor(ticket.status))
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                        
                        // QR Code
                        VStack(spacing: 16) {
                            Image(uiImage: generateQRCode(from: ticketId))
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(20)
                            
                            Text("Scan to verify")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .shadow(radius: 10)
                        
                        // Details
                        VStack(alignment: .leading, spacing: 16) {
                            DetailRow(icon: "calendar", title: "Date", value: ticket.startTime.formatted(date: .abbreviated, time: .omitted))
                            DetailRow(icon: "clock", title: "Time In", value: ticket.startTime.formatted(date: .omitted, time: .shortened))
                            DetailRow(icon: "dollarsign.circle.fill", title: "Amount", value: String(format: "$%.2f", ticket.amount))
                            DetailRow(icon: "mappin.and.ellipse", title: "Spot", value: ticket.spotId)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Action Buttons
                        if ticket.status == "active" {
                            Button(action: { showPayView = true }) {
                                Text("Pay Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        } else if ticket.status == "paid" {
                            Button(action: openBarrier) {
                                HStack {
                                    if barrierOpening {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else if barrierSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                    }
                                    
                                    Text(barrierSuccess ? "Barrier Opened!" : (barrierOpening ? "Opening..." : "Open Barrier"))
                                        .font(.headline)
                                        .fontWeight(barrierSuccess ? .bold : .regular)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(barrierSuccess ? Color.blue : Color.green)
                                .cornerRadius(16)
                            }
                            .disabled(barrierOpening || barrierSuccess)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    ProgressView("Loading Ticket...")
                        .padding(.top, 50)
                }
            }
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                fetchTicket()
            }
            .sheet(isPresented: $showPayView) {
                if let ticket = ticket {
                    PayView(ticketId: ticketId, amount: ticket.amount) {
                        fetchTicket() // Refresh after payment
                    }
                }
            }
            .alert(isPresented: $showingBarrierAlert) {
                Alert(title: Text("Barrier Control"), message: Text(barrierMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return .blue
        case "paid": return .green
        case "completed": return .gray
        default: return .primary
        }
    }
    
    private func fetchTicket() {
        let db = Firestore.firestore(database: "parking")
        db.collection("ParkingTickets").document(ticketId).getDocument { snapshot, error in
            if let document = snapshot, document.exists {
                do {
                    let decodedTicket = try document.data(as: ParkingTicket.self)
                    Task { @MainActor in
                        self.ticket = decodedTicket
                    }
                } catch {
                    print("Error decoding ticket: \(error)")
                }
            }
        }
    }
    
    private func openBarrier() {
        barrierOpening = true
        let db = Firestore.firestore(database: "parking")
        
        db.collection("Barrier").document("exitBarrier").updateData([
            "isOpen": true,
            "lastOpenedAt": FieldValue.serverTimestamp()
        ]) { [self] error in
            barrierOpening = false
            
            if let error = error {
                print("Failed to open barrier: \(error.localizedDescription)")
            } else {
                barrierSuccess = true
                print("Barrier opening... will close in 30 seconds")
                
                // Update ticket to completed
                db.collection("ParkingTickets").document(ticketId).updateData(["status": "completed"])
                
                // Close barrier after 30 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    db.collection("Barrier").document("exitBarrier").updateData([
                        "isOpen": false
                    ]) { error in
                        if let error = error {
                            print("Error closing barrier: \(error)")
                        } else {
                            print("Barrier closed automatically after 30 seconds")
                        }
                    }
                }
                
                // Hide success message and refresh after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    fetchTicket()
                    barrierSuccess = false
                }
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
