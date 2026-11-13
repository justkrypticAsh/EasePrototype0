// SpeakerNameEditSheet.swift
import SwiftUI

struct SpeakerNameEditSheet: View {
    let currentSpeakerLabel: String
    let projectId: String
    let meetingId: String
    let onSave: (String, Bool) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var newSpeakerName: String = ""
    @State private var applyToAllProjectDiscussions: Bool = true
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CURRENT SPEAKER LABEL")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        Text(currentSpeakerLabel)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.easeCyan)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(cornerRadius: 12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("IDENTIFY REAL PERSON / COLLABORATOR")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.easeCyan)

                        TextField("e.g. Aarav Mehta", text: $newSpeakerName)
                            .padding()
                            .foregroundColor(.white)
                            .glassCard(cornerRadius: 12)
                    }

                    Toggle(isOn: $applyToAllProjectDiscussions) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Update Across Entire Project Space")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Associates voice embedding profile with this participant for future discussions")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.easeCyan)
                    .padding()
                    .glassCard(cornerRadius: 14)

                    Spacer()

                    Button {
                        saveSpeakerName()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text("Save & Re-attribute Transcript")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(newSpeakerName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.4) : Color.easeCyan)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(newSpeakerName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .padding()
            }
            .navigationTitle("Edit Speaker Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }

    private func saveSpeakerName() {
        let trimmed = newSpeakerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            // Simulated backend speaker identity mapping update
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSave(trimmed, applyToAllProjectDiscussions)
                dismiss()
            }
        }
    }
}
