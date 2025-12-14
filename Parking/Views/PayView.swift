/*
 * PayView.swift
 * Smart Parking System
 * Author: Darius Toasca
 * 
 * This view handles the payment flow for parking tickets.
 * Users can pay with saved cards or enter new card details.
 * The card info is saved securely (only last 4 digits stored).
 * After successful payment, the ticket status changes to "paid".
 */

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

struct PayView: View {
    let ticketId: String
    let amount: Double
    let onPaymentSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var savedCards: [PaymentCard] = []
    @State private var selectedCard: PaymentCard?
    @State private var showNewCardForm = false
    @State private var saveCard = false
    
    // New card fields
    @State private var cardNumber = ""
    @State private var expirationDate = ""
    @State private var cvv = ""
    @State private var cardHolderName = ""
    
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoadingCards = true
    
    private let db = Firestore.firestore(database: "parking")
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Amount Header
                    VStack(spacing: 8) {
                        Text("Total Amount")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(ParkingPriceCalculator.formatPrice(amount))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    
                    // Saved Cards Section
                    if !savedCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Saved Cards")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(savedCards) { card in
                                SavedCardRow(
                                    card: card,
                                    isSelected: selectedCard?.id == card.id,
                                    onDelete: {
                                        deleteCard(card)
                                    }
                                )
                                .onTapGesture {
                                    selectedCard = card
                                    showNewCardForm = false
                                }
                            }
                            .padding(.horizontal)
                            
                            // Add New Card Button
                            Button(action: {
                                showNewCardForm = true
                                selectedCard = nil
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add New Card")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // New Card Form (shows if no saved cards or user wants to add)
                    if savedCards.isEmpty || showNewCardForm {
                        VStack(alignment: .leading, spacing: 12) {
                            if !savedCards.isEmpty {
                                Text("New Card Details")
                                    .font(.headline)
                                    .padding(.horizontal)
                            }
                            
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
                                        .onChange(of: cardNumber) { _, newValue in
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
                                            .onChange(of: expirationDate) { _, newValue in
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
                                            .onChange(of: cvv) { _, newValue in
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
                                
                                // Save Card Toggle
                                Toggle(isOn: $saveCard) {
                                    HStack {
                                        Image(systemName: "creditcard.fill")
                                            .foregroundColor(.blue)
                                        Text("Save card for future payments")
                                            .font(.subheadline)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(10)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                    }
                    
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
            .onAppear {
                loadSavedCards()
            }
        }
    }
    
    private var isValid: Bool {
        if let _ = selectedCard {
            return true
        }
        return cardNumber.count == 16 && expirationDate.count >= 4 && cvv.count == 3 && !cardHolderName.isEmpty
    }
    
    private func loadSavedCards() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot load cards: no userId")
            return
        }
        
        print("🔍 Loading saved cards for user: \(userId)")
        
        db.collection("Users").document(userId).collection("CreditCardDetails")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                isLoadingCards = false
                if let error = error {
                    print("❌ Error loading saved cards: \(error.localizedDescription)")
                    return
                }
                
                print("📄 Found \(snapshot?.documents.count ?? 0) card document(s)")
                
                Task { @MainActor in
                    savedCards = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        print("📋 Card doc data: \(data)")
                        return try? doc.data(as: PaymentCard.self)
                    } ?? []
                    
                    print("✅ Loaded \(savedCards.count) card(s)")
                    
                    // Auto-select first card if available
                    if let first = savedCards.first {
                        selectedCard = first
                        print("🎯 Auto-selected card: \(first.displayName)")
                    }
                }
            }
    }
    
    private func deleteCard(_ card: PaymentCard) {
        guard let userId = Auth.auth().currentUser?.uid,
              let cardId = card.id else {
            print("❌ Cannot delete card: missing userId or cardId")
            return
        }
        
        print("🗑️ Deleting card: \(cardId)")
        
        // Remove from local array first for immediate UI update
        if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
            savedCards.remove(at: index)
        }
        
        // Clear selection if deleted card was selected
        if selectedCard?.id == card.id {
            selectedCard = savedCards.first
        }
        
        // Delete from Firestore
        db.collection("Users").document(userId).collection("CreditCardDetails").document(cardId).delete { error in
            if let error = error {
                print("❌ Error deleting card: \(error.localizedDescription)")
                // Reload cards to restore state
                self.loadSavedCards()
            } else {
                print("✅ Card deleted successfully")
            }
        }
    }
    
    private func processPayment() {
        print("🔄 Processing payment... saveCard: \(saveCard), selectedCard: \(selectedCard?.id ?? "none")")
        isProcessing = true
        
        // If using new card and saveCard is true, save it first
        if selectedCard == nil && saveCard {
            print("💳 Attempting to save new card...")
            saveNewCard { success in
                if success {
                    print("✅ Card saved, proceeding with payment")
                } else {
                    print("⚠️ Card save failed, but proceeding with payment")
                }
                self.completePayment()
            }
        } else {
            print("💳 Using existing card or not saving, proceeding with payment")
            completePayment()
        }
    }
    
    private func completePayment() {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Update ticket status in Firestore
            // Use client-side timestamp to ensure immediate listener updates
            self.db.collection("ParkingTickets").document(self.ticketId).updateData([
                "status": "paid",
                "paidAt": Timestamp(date: Date())
            ]) { error in
                self.isProcessing = false
                if let error = error {
                    self.alertMessage = "Payment failed: \(error.localizedDescription)"
                } else {
                    self.alertMessage = "Payment Successful!"
                }
                self.showingAlert = true
            }
        }
    }
    
    private func saveNewCard(completion: @escaping (Bool) -> Void) {
        print("💾 saveNewCard called")
        
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("❌ Cannot save card: no userId")
            completion(false)
            return 
        }
        
        guard cardNumber.count == 16 else {
            print("❌ Cannot save card: invalid card number length (\(cardNumber.count))")
            completion(false)
            return
        }
        
        let last4 = String(cardNumber.suffix(4))
        let cardType = detectCardType(cardNumber: cardNumber)
        let expComponents = expirationDate.split(separator: "/")
        
        guard expComponents.count == 2 else { 
            print("❌ Cannot save card: invalid expiration format")
            completion(false)
            return 
        }
        
        print("💳 Saving card: type=\(cardType), last4=\(last4), userId=\(userId)")
        
        // Data for Cloud Function (includes full card number for processing)
        let cloudFunctionData: [String: Any] = [
            "cardNumber": cardNumber,
            "expirationDate": expirationDate,
            "cvv": cvv,
            "cardType": cardType,
            "cardHolderName": cardHolderName,
            "expiryMonth": String(expComponents[0]),
            "expiryYear": String(expComponents[1]),
            "isDefault": savedCards.isEmpty
        ]
        
        print("☁️ Calling savePaymentCard Cloud Function...")
        let functions = Functions.functions(region: "europe-central2")
        functions.httpsCallable("savePaymentCard").call(cloudFunctionData) { result, error in
            if let error = error {
                print("❌ Cloud Function Error: \(error.localizedDescription)")
                print("⚠️ Falling back to direct Firestore write...")
                
                // Fallback: Write directly to Firestore with correct model fields
                let fallbackCardData: [String: Any] = [
                    "userId": userId,
                    "last4Digits": last4,
                    "cardType": cardType,
                    "cardHolderName": cardHolderName,
                    "expiryMonth": String(expComponents[0]),
                    "expiryYear": String(expComponents[1]),
                    "isDefault": self.savedCards.isEmpty,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                self.db.collection("Users").document(userId).collection("CreditCardDetails").addDocument(data: fallbackCardData) { error in
                    if let error = error {
                        print("❌ Fallback Error: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Card saved successfully via Fallback (Direct Write)!")
                        self.loadSavedCards()
                        completion(true)
                    }
                }
            } else {
                print("✅ Card saved successfully via Cloud Function!")
                // Refresh cards
                self.loadSavedCards()
                completion(true)
            }
        }
    }
    
    private func detectCardType(cardNumber: String) -> String {
        let firstDigit = cardNumber.prefix(1)
        let firstTwo = cardNumber.prefix(2)
        
        if firstDigit == "4" {
            return "Visa"
        } else if ["51", "52", "53", "54", "55"].contains(firstTwo) {
            return "Mastercard"
        } else if ["34", "37"].contains(firstTwo) {
            return "Amex"
        } else if firstTwo == "65" || cardNumber.hasPrefix("6011") {
            return "Discover"
        }
        return "Card"
    }
}

// MARK: - Saved Card Row

struct SavedCardRow: View {
    let card: PaymentCard
    let isSelected: Bool
    var onDelete: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: cardIcon)
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Expires \(card.expiryDisplay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
            
            // Delete button
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var cardIcon: String {
        switch card.cardType.lowercased() {
        case "visa":
            return "creditcard.fill"
        case "mastercard":
            return "creditcard.circle.fill"
        case "amex":
            return "creditcard.trianglebadge.exclamationmark"
        default:
            return "creditcard"
        }
    }
}
