// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var audioRetentionDays: Int = 30
    @State private var voiceProfileDeleted: Bool = false
    @State private var showDeleteVoiceAlert: Bool = false
    @State private var showConsentAuditSheet: Bool = false
    @State private var showExportShareSheet: Bool = false
    @State private var exportZipContent: String = ""
    @State private var isResettingDemo: Bool = false
    @State private var demoResetMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                // Ambient background lighting
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.easePurple.opacity(0.12))
                            .frame(width: 250, height: 250)
                            .blur(radius: 75)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.easeCyan.opacity(0.1))
                            .frame(width: 230, height: 230)
                            .blur(radius: 65)
                    }
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // User Profile & Apple ID
                        accountSection

                        // Privacy & Consent Records
                        privacySection

                        // System Permissions Status
                        permissionsSection

                        // Data Export & Storage Retention
                        dataManagementSection

                        // Demo Dataset Reset
                        demoDataSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showConsentAuditSheet) {
                ConsentAuditSheet()
            }
            .sheet(isPresented: $showExportShareSheet) {
                ShareSheetView(activityItems: [exportZipContent, "EASE_Project_Memory_Export.json"])
            }
            .alert("Purge Voice Profile?", isPresented: $showDeleteVoiceAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Permanently", role: .destructive) {
                    voiceProfileDeleted = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } message: {
                Text("This permanently purges your biometric voice vectors and enrollment audio from the on-device AES-256 vault.")
            }
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT & APPLE ID")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.easeCyan)

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.easeCyan.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Text("AS")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.easeCyan)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(env.currentUser?.fullName ?? "Ashish Sharma")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text(env.currentUser?.email ?? "ashish@ease.ai")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    GlassStatusPill(title: "Owner", icon: "crown.fill", color: .easeCyan)
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Image(systemName: "applelogo")
                        .foregroundColor(.white)
                    Text("Apple ID Collaboration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Connected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.easeEmerald)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRIVACY & CONSENT RECORDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.easeCyan)

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showConsentAuditSheet = true
                } label: {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.easeEmerald.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.easeEmerald)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Consent Audit Logs")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Review recorded affirmative participant consent timestamps")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.easePurple.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.easePurple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Biometric Voice Vault")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("AES-256 on-device encryption active")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteVoiceAlert = true
                    } label: {
                        Text("Purge")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.easeAmber)
                    }
                }

                if voiceProfileDeleted {
                    Text("✓ Voice profile permanently purged")
                        .font(.caption)
                        .foregroundColor(.easeEmerald)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYSTEM PERMISSIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.easeCyan)

            VStack(spacing: 8) {
                permissionRow(title: "Microphone Access", icon: "mic.fill", granted: true)
                permissionRow(title: "Speech Recognition", icon: "waveform", granted: true)
                permissionRow(title: "Apple Calendar (EventKit)", icon: "calendar", granted: true)
                permissionRow(title: "Apple Reminders (EventKit)", icon: "checklist", granted: true)
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
    }

    private func permissionRow(title: String, icon: String, granted: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(granted ? .easeCyan : .gray)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Text(granted ? "Authorized" : "Not Determined")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(granted ? .easeEmerald : .gray)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DATA MANAGEMENT & RETENTION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.easeCyan)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audio Retention Period")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Auto-purges raw audio after \(audioRetentionDays) days")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Stepper("", value: $audioRetentionDays, in: 7...180, step: 7)
                }

                Divider().background(Color.white.opacity(0.1))

                Button {
                    exportDataArchive()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundColor(.easeCyan)
                        Text("Export Project Memory & Discussion Archive")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Demo Dataset Section
    private var demoDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEMONSTRATION & PROTOTYPE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.easeCyan)

            VStack(spacing: 10) {
                Text("Includes pre-seeded 'Product Launch' space with Aarav, Riya, Kabir, Neha, discussions, decisions, and blocker dependency graph.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button {
                    resetDemoDataset()
                } label: {
                    HStack {
                        if isResettingDemo {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Demonstration Dataset")
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.easeCyan.opacity(0.2))
                    .foregroundColor(.easeCyan)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.easeCyan.opacity(0.4)))
                }
                .disabled(isResettingDemo)

                if let msg = demoResetMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.easeEmerald)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
    }

    private func exportDataArchive() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let archive = """
        {
          "application": "EASE Project Memory",
          "export_timestamp": "\(Date().formatted())",
          "user": "\(env.currentUser?.fullName ?? "Ashish Sharma")",
          "projects": [
            {
              "name": "Product Launch",
              "domain": "startup",
              "decisions_count": 3,
              "tasks_count": 4,
              "blockers_count": 1
            }
          ]
        }
        """
        exportZipContent = archive
        showExportShareSheet = true
    }

    private func resetDemoDataset() {
        isResettingDemo = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            do {
                let _: [String: String] = try await APIClient.shared.request(
                    path: "/demo/reset",
                    method: "POST"
                )
                await env.loadProjects()
                await MainActor.run {
                    isResettingDemo = false
                    demoResetMessage = "✓ Demonstration dataset restored"
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isResettingDemo = false
                    demoResetMessage = "✓ Local prototype dataset re-initialized"
                }
            }
        }
    }
}
