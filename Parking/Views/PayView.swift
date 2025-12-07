import SwiftUI
import FirebaseFirestore

struct PayView: View {
    let ticketId: String
    let amount: Double
    let onPaymentSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var cardNumber = ""
    @State private var expirationDate = ""
    @State private var cvv = ""
    @State private var cardHolderName = ""
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Amount Header
                    VStack(spacing: 8) {
                        Text("Total Amount")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "$%.2f", amount))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    
                    // Card Details Form
                    VStack(spacing: 20) {
                        // Card Number
                        VStack(alignment: .leading) {
                            Text("Card Number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("0000 0000 0000 0000", text: $cardNumber)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .onChange(of: cardNumber) { newValue in
                                    // Simple formatting logic could go here
                                    if newValue.count > 16 {
                                        cardNumber = String(newValue.prefix(16))
                                    }
                                }
                        }
                        
                        HStack(spacing: 16) {
                            // Expiration
                            VStack(alignment: .leading) {
                                Text("Expires")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("MM/YY", text: $expirationDate)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .onChange(of: expirationDate) { newValue in
                                        if newValue.count > 5 {
                                            expirationDate = String(newValue.prefix(5))
                                        }
                                    }
                            }
                            
                            // CVV
                            VStack(alignment: .leading) {
                                Text("CVV")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("123", text: $cvv)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .onChange(of: cvv) { newValue in
                                        if newValue.count > 3 {
                                            cvv = String(newValue.prefix(3))
                                        }
                                    }
                            }
                        }
                        
                        // Card Holder
                        VStack(alignment: .leading) {
                            Text("Card Holder Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("John Doe", text: $cardHolderName)
                                .autocapitalization(.words)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Pay Button
                    Button(action: processPayment) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Pay Now")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(isValid ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(!isValid || isProcessing)
                }
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Payment"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("Success") {
                        onPaymentSuccess()
                        dismiss()
                    }
                })
            }
        }
    }
    
    private var isValid: Bool {
        return cardNumber.count == 16 && expirationDate.count >= 4 && cvv.count == 3 && !cardHolderName.isEmpty
    }
    
    private func processPayment() {
        isProcessing = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Update ticket status in Firestore
            let db = Firestore.firestore(database: "parking")
            db.collection("ParkingTickets").document(ticketId).updateData([
                "status": "paid",
                "paidAt": FieldValue.serverTimestamp()
            ]) { error in
                isProcessing = false
                if let error = error {
                    alertMessage = "Payment failed: \(error.localizedDescription)"
                } else {
                    alertMessage = "Payment Successful!"
                }
                showingAlert = true
            }
        }
    }
}
