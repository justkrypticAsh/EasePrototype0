// ConsentAuditSheet.swift
import SwiftUI

struct ConsentAuditLogItem: Identifiable, Codable {
    let id: String
    let meetingTitle: String
    let projectName: String
    let date: String
    let participants: [String]
    let spokenAnnouncementPlayed: Bool
    let allConsented: Bool
    let storageType: String
}

struct ConsentAuditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var purgeAlertPresented: Bool = false
    @State private var purgedItem: ConsentAuditLogItem?

    @State private var auditLogs: [ConsentAuditLogItem] = [
        ConsentAuditLogItem(
            id: "consent-launch-001",
            meetingTitle: "Product Launch Architecture & Scope",
            projectName: "Product Launch",
            date: "Nov 10, 2026 • 14:30:15",
            participants: ["Aarav Mehta", "Riya Sharma", "Kabir Singh"],
            spokenAnnouncementPlayed: true,
            allConsented: true,
            storageType: "AES-256 Fernet Voice Vault"
        ),
        ConsentAuditLogItem(
            id: "consent-launch-002",
            meetingTitle: "Security Audit & Launch Readiness",
            projectName: "Product Launch",
            date: "Nov 13, 2026 • 18:15:02",
            participants: ["Aarav Mehta", "Neha Kapoor"],
            spokenAnnouncementPlayed: true,
            allConsented: true,
            storageType: "AES-256 Fernet Voice Vault"
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Consent Records & Vault Audit")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Immutable records of explicit participant consent and spoken notice compliance.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        // Policy badge
                        HStack(spacing: 10) {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.easeEmerald)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Affirmative Consent Policy Enforced")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("No audio is processed without verified participant opt-in.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .glassCard(cornerRadius: 12, glowColor: .easeEmerald, glowRadius: 2)

                        // Logs List
                        VStack(spacing: 14) {
                            ForEach(auditLogs) { log in
                                auditCard(log)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Consent Audit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.easeCyan)
                }
            }
            .alert("Purge Voice Vault Data?", isPresented: $purgeAlertPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Purge Permanently", role: .destructive) {
                    if let item = purgedItem {
                        auditLogs.removeAll { $0.id == item.id }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } message: {
                Text("This permanently deletes all biometric voice embeddings and audio associated with this session. This action cannot be undone.")
            }
        }
    }

    private func auditCard(_ log: ConsentAuditLogItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(log.projectName.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.easeCyan.opacity(0.2))
                    .foregroundColor(.easeCyan)
                    .clipShape(Capsule())

                Spacer()

                GlassStatusPill(title: "Consented", icon: "checkmark.seal.fill", color: .easeEmerald)
            }

            Text(log.meetingTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Timestamp: \(log.date)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Participants Consented:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                HStack {
                    ForEach(log.participants, id: \.self) { p in
                        Text(p)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                    Text(log.storageType)
                        .font(.system(size: 10))
                }
                .foregroundColor(.easeCyan)

                Spacer()

                Button(role: .destructive) {
                    purgedItem = log
                    purgeAlertPresented = true
                } label: {
                    Text("Purge Vault")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.easeAmber)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

