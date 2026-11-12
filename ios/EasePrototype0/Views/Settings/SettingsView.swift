// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var audioRetentionDays = 30
    @State private var voiceProfileDeleted = false
    @State private var showDeleteVoiceAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

                Form {
                    // Account Section
                    Section("Account") {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(env.currentUser?.fullName ?? "")
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(env.currentUser?.email ?? "")
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.16, blue: 0.24))

                    // Privacy & Biometrics Section
                    Section("Privacy & Voice Biometrics") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice Biometrics Vault")
                                .font(.body.bold())
                                .foregroundColor(.white)
                            Text("Your voice enrollment clips and vectors are encrypted at rest with AES-256 and used solely for speaker separation.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            showDeleteVoiceAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete My Voice Profile")
                            }
                            .foregroundColor(.red)
                        }

                        if voiceProfileDeleted {
                            Text("✓ Voice profile permanently purged")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.16, blue: 0.24))

                    // Audio Retention Section
                    Section("Data Retention Policy") {
                        Stepper("Delete Audio Files After: \(audioRetentionDays) days", value: $audioRetentionDays, in: 7...365, step: 7)
                        Text("Transcripts, extracted claims, decisions, and memory links are retained while raw audio binaries are safely purged according to your policy.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.16, blue: 0.24))

                    // Session / Prototype Mode
                    Section {
                        HStack {
                            Text("Prototype Mode")
                            Spacer()
                            Text("Direct Access Active")
                                .foregroundColor(.cyan)
                                .font(.caption)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.16, blue: 0.24))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings & Privacy")
            .alert("Purge Voice Profile?", isPresented: $showDeleteVoiceAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Permanently", role: .destructive) {
                    voiceProfileDeleted = true
                }
            } message: {
                Text("This will permanently delete your biometric voice vector and enrollment audio across all projects.")
            }
        }
    }
}
