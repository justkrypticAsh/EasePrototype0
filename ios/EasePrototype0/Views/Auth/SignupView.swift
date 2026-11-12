// SignupView.swift
import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var env: AppEnvironment

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Create EASE Account")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top)

                VStack(spacing: 14) {
                    TextField("Full Name", text: $fullName)
                        .padding()
                        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    SecureField("Password (min 8 chars)", text: $password)
                        .padding()
                        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button(action: handleSignup) {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                .disabled(isLoading || fullName.isEmpty || email.isEmpty || password.count < 8)

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.gray)

                Spacer()
            }
            .padding()
        }
    }

    private func handleSignup() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let payload: [String: String] = [
                    "email": email.trimmingCharacters(in: .whitespaces),
                    "password": password,
                    "full_name": fullName.trimmingCharacters(in: .whitespaces)
                ]
                let body = try JSONEncoder().encode(payload)
                let tokenResp: TokenResponse = try await APIClient.shared.request(path: "/auth/signup", method: "POST", body: body)
                await MainActor.run {
                    env.setSession(tokenResp: tokenResp)
                    dismiss()
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
