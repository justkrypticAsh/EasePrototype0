// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Logo & App Name
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("EASE")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Executive Discussion Intelligence")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    // Input Fields
                    VStack(spacing: 16) {
                        TextField("Work Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Sign In Button
                    Button(action: handleLogin) {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal)

                    // Sign up switch
                    Button("Don't have an account? Sign Up") {
                        showSignup = true
                    }
                    .font(.footnote)
                    .foregroundColor(.cyan)

                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showSignup) {
                SignupView()
            }
        }
    }

    private func handleLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let payload: [String: String] = ["email": email.trimmingCharacters(in: .whitespaces), "password": password]
                let body = try JSONEncoder().encode(payload)
                let tokenResp: TokenResponse = try await APIClient.shared.request(path: "/auth/login", method: "POST", body: body)
                await MainActor.run {
                    env.setSession(tokenResp: tokenResp)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
