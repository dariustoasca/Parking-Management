import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
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
    @State private var isPendingExit = false
    @State private var exitRemainingTime = 60
    @State private var exitTimer: Timer?
    
    private let functions = Functions.functions(region: "europe-central2")
    
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
                            DetailRow(icon: "calendar", title: "Date In", value: ticket.startTime.formatted(date: .abbreviated, time: .shortened))
                            if let endTime = ticket.endTime {
                                DetailRow(icon: "calendar.badge.checkmark", title: "Date Out", value: endTime.formatted(date: .abbreviated, time: .shortened))
                            }
                            DetailRow(icon: "clock", title: "Time", value: formatDuration(from: ticket.startTime, to: ticket.endTime ?? Date()))
                            DetailRow(icon: "dollarsign.circle.fill", title: "Amount", value: ParkingPriceCalculator.formatPrice(ParkingPriceCalculator.calculatePrice(from: ticket.startTime, to: ticket.endTime ?? Date())))
                            DetailRow(icon: "mappin.and.ellipse", title: "Spot", value: formatSpotName(ticket.spotId))
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
                                    } else if isPendingExit {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else if barrierSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        if isPendingExit {
                                            Text("Waiting for Button...")
                                                .font(.headline)
                                            Text("\(exitRemainingTime)s - Press barrier button to exit")
                                                .font(.caption)
                                        } else if barrierSuccess {
                                            Text("Barrier Opened!")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                        } else {
                                            Text("Open Exit Barrier")
                                                .font(.headline)
                                        }
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isPendingExit ? Color.orange : (barrierSuccess ? Color.blue : Color.green))
                                .cornerRadius(16)
                            }
                            .disabled(barrierOpening || barrierSuccess || isPendingExit)
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
                    PayView(ticketId: ticketId, amount: ParkingPriceCalculator.calculatePrice(from: ticket.startTime)) {
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
        case "active": return .green
        case "paid": return .blue
        case "completed": return .gray
        default: return .primary
        }
    }
    
    private func formatSpotName(_ spotId: String) -> String {
        // Extract just the number from "spot1", "spot2", etc.
        if let number = spotId.last, number.isNumber {
            return String(number)
        }
        return spotId
    }
    
    private func formatDuration(from startTime: Date, to endTime: Date) -> String {
        let interval = endTime.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
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
        isPendingExit = false
        exitRemainingTime = 60
        
        // Call the cloud function
        functions.httpsCallable("requestParkingExit").call([:]) { [self] result, error in
            barrierOpening = false
            
            if let error = error {
                print("Error requesting exit: \(error.localizedDescription)")
                barrierMessage = "Failed to request exit: \(error.localizedDescription)"
                showingBarrierAlert = true
                return
            }
            
            // Start pending exit state with countdown
            isPendingExit = true
            startExitTimer()
            print("Exit request successful, waiting for barrier button...")
        }
    }
    
    private func startExitTimer() {
        exitTimer?.invalidate()
        exitRemainingTime = 60
        
        // Listen for barrier opening
        let db = Firestore.firestore(database: "parking")
        db.collection("Barrier").document("exitBarrier")
            .addSnapshotListener { [self] snapshot, error in
                if let isOpen = snapshot?.data()?["isOpen"] as? Bool, isOpen {
                    // Barrier opened!
                    isPendingExit = false
                    exitTimer?.invalidate()
                    barrierSuccess = true
                    
                    // Refresh ticket and hide success after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        fetchTicket()
                        barrierSuccess = false
                    }
                }
            }
        
        // Countdown timer
        exitTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            exitRemainingTime -= 1
            if exitRemainingTime <= 0 {
                exitTimer?.invalidate()
                isPendingExit = false
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
