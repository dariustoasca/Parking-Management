import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isSecured = true
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSignUpMode = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Logo / Header
                    VStack(spacing: 15) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .shadow(radius: 10)
                            )
                        
                        Text("Parking App")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(isSignUpMode ? "Create your account" : "Welcome back, please sign in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Display Name (Sign Up only)
                        if isSignUpMode {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                TextField("Full Name", text: $displayName)
                                    .autocapitalization(.words)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        
                        // Email Field
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Password Field
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                            
                            if isSecured {
                                SecureField("Password", text: $password)
                            } else {
                                TextField("Password", text: $password)
                            }
                            
                            Button(action: { isSecured.toggle() }) {
                                Image(systemName: isSecured ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Confirm Password (Sign Up only)
                        if isSignUpMode {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                SecureField("Confirm Password", text: $confirmPassword)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        
                        // Forgot Password (Sign In only)
                        if !isSignUpMode {
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showResetPassword = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Button
                    Button(action: isSignUpMode ? signUp : signIn) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isSignUpMode ? "Create Account" : "Sign In")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    .disabled(authManager.isLoading)
                    
                    // Toggle Mode Button
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUpMode.toggle()
                            // Clear fields when switching
                            password = ""
                            confirmPassword = ""
                        }
                    }) {
                        HStack {
                            Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(.secondary)
                            Text(isSignUpMode ? "Sign In" : "Sign Up")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .font(.subheadline)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordView()
        }
    }
    
    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please enter both email and password."
            showingAlert = true
            return
        }
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password, enableBiometric: false)
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func signUp() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all required fields."
            showingAlert = true
            return
        }
        
        guard password == confirmPassword else {
            alertMessage = "Passwords do not match."
            showingAlert = true
            return
        }
        
        guard password.count >= 6 else {
            alertMessage = "Password must be at least 6 characters."
            showingAlert = true
            return
        }
        
        Task {
            do {
                try await authManager.signUp(email: email, password: password, displayName: displayName)
            } catch {
                alertMessage = authManager.errorMessage ?? error.localizedDescription
                showingAlert = true
            }
        }
    }
}

struct ResetPasswordView: View {
    @State private var email = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button(action: sendResetLink) {
                    Text("Send Reset Link")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 50)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
    
    private func sendResetLink() {
        guard !email.isEmpty else { return }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                alertMessage = error.localizedDescription
            } else {
                alertMessage = "Reset link sent! Check your email."
            }
            showingAlert = true
        }
    }
}
