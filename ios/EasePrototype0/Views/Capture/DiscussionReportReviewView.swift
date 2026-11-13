// DiscussionReportReviewView.swift
import SwiftUI

struct DiscussionReportReviewView: View {
    let meetingTitle: String
    let projectName: String
    let onCommit: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var acceptedDecisions: Set<Int> = [0, 1]
    @State private var acceptedClaims: Set<Int> = [0, 1]
    @State private var acceptedTasks: Set<Int> = [0, 1, 2]
    @State private var isCommitting: Bool = false

    let sampleDecisions = [
        "Adopt Gemini Flash 1.5 for sub-1.2s discussion intelligence",
        "Enforce AES-256 encrypted local biometric voice vault on iOS"
    ]

    let sampleClaims = [
        (text: "Gemini Flash meets 1.2s round-trip latency SLA", speaker: "Riya Sharma", type: "fact_claim"),
        (text: "Production database sharding requires 48 hours migration window", speaker: "Kabir Singh", type: "estimate")
    ]

    let sampleTasks = [
        (task: "Finalize Client Security Architecture & Sign-off", owner: "Riya Sharma", blocker: nil as String?),
        (task: "Deploy Production PostgreSQL Sharding & Migration", owner: "Kabir Singh", blocker: "Riya's Security Sign-off" as String?),
        (task: "Draft Biometric Consent Protocol Agreement", owner: "Aarav Mehta", blocker: nil as String?)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Intelligence Review")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Review extracted knowledge before committing to \(projectName)'s memory space")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        // Decisions Review
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Decisions Detected (\(sampleDecisions.count))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.easeCyan)
                                Spacer()
                                Text("Select to transfer")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }

                            ForEach(0..<sampleDecisions.count, id: \.self) { idx in
                                HStack {
                                    Image(systemName: acceptedDecisions.contains(idx) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(acceptedDecisions.contains(idx) ? .easeEmerald : .gray)

                                    Text(sampleDecisions[idx])
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)

                                    Spacer()
                                }
                                .padding(12)
                                .glassCard(cornerRadius: 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if acceptedDecisions.contains(idx) {
                                        acceptedDecisions.remove(idx)
                                    } else {
                                        acceptedDecisions.insert(idx)
                                    }
                                }
                            }
                        }

                        // Claims Review
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Key Claims & Estimates (\(sampleClaims.count))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.easePurple)
                                Spacer()
                            }

                            ForEach(0..<sampleClaims.count, id: \.self) { idx in
                                let claim = sampleClaims[idx]
                                HStack {
                                    Image(systemName: acceptedClaims.contains(idx) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(acceptedClaims.contains(idx) ? .easeCyan : .gray)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(claim.text)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                        Text("\(claim.speaker) • \(claim.type.uppercased())")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .glassCard(cornerRadius: 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if acceptedClaims.contains(idx) {
                                        acceptedClaims.remove(idx)
                                    } else {
                                        acceptedClaims.insert(idx)
                                    }
                                }
                            }
                        }

                        // Tasks & Blockers Review
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Prerequisites & Action Items (\(sampleTasks.count))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.easeAmber)
                                Spacer()
                            }

                            ForEach(0..<sampleTasks.count, id: \.self) { idx in
                                let item = sampleTasks[idx]
                                HStack {
                                    Image(systemName: acceptedTasks.contains(idx) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(acceptedTasks.contains(idx) ? .easeAmber : .gray)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.task)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)

                                        HStack(spacing: 6) {
                                            Text("Owner: \(item.owner)").font(.caption2).foregroundColor(.gray)
                                            if let b = item.blocker {
                                                Text("• Blocked by \(b)").font(.caption2).foregroundColor(.easeAmber)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .glassCard(cornerRadius: 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if acceptedTasks.contains(idx) {
                                        acceptedTasks.remove(idx)
                                    } else {
                                        acceptedTasks.insert(idx)
                                    }
                                }
                            }
                        }

                        // Action Button
                        Button {
                            commitReport()
                        } label: {
                            HStack {
                                if isCommitting {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "arrow.up.forward.app.fill")
                                    Text("Commit to Project Memory & Tasks")
                                }
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.easeCyan)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isCommitting)
                    }
                    .padding()
                }
            }
            .navigationTitle("Report Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }

    private func commitReport() {
        isCommitting = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                isCommitting = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onCommit()
                dismiss()
            }
        }
    }
}
