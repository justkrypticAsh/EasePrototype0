// DecisionHistoryView.swift
import SwiftUI

struct DecisionHistoryEntry: Identifiable, Codable {
    let id: String
    let meetingTitle: String
    let meetingDate: String
    let decisionText: String
    let decidedBy: String
    let relationType: String? // "CONFIRMS", "UPDATES", "SUPERSEDES", "INITIAL"
    let relationReason: String?
    let timestampMs: Int
}

struct DecisionHistoryView: View {
    let projectId: String
    @Environment(\.dismiss) var dismiss

    @State private var historyEntries: [DecisionHistoryEntry] = [
        DecisionHistoryEntry(
            id: "dh-001",
            meetingTitle: "Security Audit & Launch Readiness",
            meetingDate: "Nov 13, 2026 • 18:15",
            decisionText: "Confirmed zero unconsented audio transmission policy and instant purge option",
            decidedBy: "Aarav Mehta",
            relationType: "CONFIRMS",
            relationReason: "Re-affirms AES-256 local vault encryption policy agreed in kickoff meeting.",
            timestampMs: 5000
        ),
        DecisionHistoryEntry(
            id: "dh-002",
            meetingTitle: "Product Launch Architecture & Scope",
            meetingDate: "Nov 10, 2026 • 14:30",
            decisionText: "Enforce AES-256 encrypted local biometric voice vault on iOS",
            decidedBy: "Aarav Mehta",
            relationType: "INITIAL",
            relationReason: "Baseline architectural decision for privacy-first on-device processing.",
            timestampMs: 55200
        ),
        DecisionHistoryEntry(
            id: "dh-003",
            meetingTitle: "Product Launch Architecture & Scope",
            meetingDate: "Nov 10, 2026 • 14:30",
            decisionText: "Adopt Gemini Flash 1.5 for sub-1.2s discussion intelligence",
            decidedBy: "Aarav Mehta",
            relationType: "INITIAL",
            relationReason: "Selected after benchmarking 1.1s round-trip response time.",
            timestampMs: 14200
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                // Ambient glow
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.easeCyan.opacity(0.12))
                            .frame(width: 250, height: 250)
                            .blur(radius: 70)
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Decision Evolution & Traceability")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Track how key decisions evolve, update, or confirm earlier agreements")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        // Timeline items
                        VStack(spacing: 16) {
                            ForEach(historyEntries) { entry in
                                decisionHistoryCard(entry)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Decision History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.easeCyan)
                }
            }
        }
    }

    private func decisionHistoryCard(_ entry: DecisionHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline track icon
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(pillColor(for: entry.relationType).opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconName(for: entry.relationType))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(pillColor(for: entry.relationType))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let rel = entry.relationType {
                        Text(rel)
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(pillColor(for: rel).opacity(0.2))
                            .foregroundColor(pillColor(for: rel))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(entry.meetingDate)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                Text(entry.decisionText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let reason = entry.relationReason {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 11))
                        Text("Decided by \(entry.decidedBy)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.easeCyan)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                        Text(entry.meetingTitle)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
    }

    private func pillColor(for relation: String?) -> Color {
        switch relation {
        case "CONFIRMS": return .easeEmerald
        case "UPDATES", "SUPERSEDES": return .easeCyan
        case "CONTRADICTS": return .easeAmber
        default: return .easePurple
        }
    }

    private func iconName(for relation: String?) -> String {
        switch relation {
        case "CONFIRMS": return "checkmark.seal.fill"
        case "UPDATES", "SUPERSEDES": return "arrow.triangle.2.circlepath"
        case "CONTRADICTS": return "exclamationmark.triangle.fill"
        default: return "sparkles"
        }
    }
}
