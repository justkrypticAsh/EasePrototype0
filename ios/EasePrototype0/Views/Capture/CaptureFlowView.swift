// CaptureFlowView.swift
import SwiftUI

enum CaptureStep {
    case selectProject
    case participantsAndConsent
    case recording
    case uploading
    case done
}

struct CaptureFlowView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var speechSynth = SpeechSynthesizerService.shared

    @State private var currentStep: CaptureStep = .selectProject
    @State private var selectedProject: Project?
    @State private var meetingTitle = ""

    // Participants & Consent
    @State private var participantInput = ""
    @State private var participantsList: [String] = []
    @State private var hasAffirmativeConsent = false
    @State private var consentAnnouncementPlayed = false
    @State private var voiceEnrollmentOptIn = false

    // Upload & Result
    @State private var recordedAudioURL: URL?
    @State private var isUploading = false
    @State private var uploadErrorMessage: String?
    @State private var createdMeetingSummary: MeetingSummary?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

                VStack {
                    switch currentStep {
                    case .selectProject:
                        selectProjectStep
                    case .participantsAndConsent:
                        consentStep
                    case .recording:
                        recordingStep
                    case .uploading:
                        uploadingStep
                    case .done:
                        doneStep
                    }
                }
                .padding()
            }
            .navigationTitle("New Discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if recorder.isRecording {
                            _ = recorder.stopRecording()
                        }
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            if let active = env.activeProject {
                selectedProject = active
                currentStep = .participantsAndConsent
            }
        }
    }

    // Step 1: Select Project
    private var selectProjectStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Target Project")
                .font(.headline)
                .foregroundColor(.white)

            List(env.projects) { proj in
                Button {
                    selectedProject = proj
                    currentStep = .participantsAndConsent
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(proj.name)
                                .font(.body.bold())
                                .foregroundColor(.white)
                            Text(proj.domain.capitalized)
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .listRowBackground(Color(red: 0.12, green: 0.16, blue: 0.24))
            }
            .listStyle(.plain)
        }
    }

    // Step 2: Participants & Mandatory Consent
    private var consentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Discussion Title")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    TextField("e.g. Q4 Architectural Review", text: $meetingTitle)
                        .padding()
                        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }

                // Participants
                VStack(alignment: .leading, spacing: 6) {
                    Text("In-Person Participants")
                        .font(.caption.bold())
                        .foregroundColor(.gray)

                    HStack {
                        TextField("Add name (e.g. Rohan, Priya)", text: $participantInput)
                            .padding()
                            .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                            .cornerRadius(8)
                            .foregroundColor(.white)

                        Button("Add") {
                            let trimmed = participantInput.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                participantsList.append(trimmed)
                                participantInput = ""
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }

                    // Chips
                    FlowLayout(spacing: 8) {
                        ForEach(participantsList, id: \.self) { p in
                            HStack(spacing: 4) {
                                Text(p).foregroundColor(.white).font(.subheadline)
                                Button {
                                    participantsList.removeAll { $0 == p }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.16, green: 0.22, blue: 0.32))
                            .cornerRadius(16)
                        }
                    }
                }

                // Spoken Consent Policy Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.cyan)
                        Text("Mandatory Consent Protocol")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Text("Recording requires explicit notice and affirmative consent from everyone present in the room.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    // Spoken announcement player
                    Button {
                        let text = "Notice: This discussion is being captured for project memory and action item extraction. Please affirm if you agree."
                        speechSynth.speak(text: text)
                        consentAnnouncementPlayed = true
                    } label: {
                        HStack {
                            Image(systemName: speechSynth.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            Text(speechSynth.isSpeaking ? "Playing Announcement..." : "Play Spoken Consent Announcement")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.18, green: 0.24, blue: 0.36))
                        .foregroundColor(.cyan)
                        .cornerRadius(8)
                    }

                    // Consent confirmation check
                    Toggle(isOn: $hasAffirmativeConsent) {
                        Text("All present participants have explicitly consented to be recorded")
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    .tint(.cyan)

                    Toggle(isOn: $voiceEnrollmentOptIn) {
                        VStack(alignment: .leading) {
                            Text("Opt-in to Biometric Voice Profile")
                                .font(.footnote)
                                .foregroundColor(.white)
                            Text("Enables accurate speaker identity matching. Encrypted at rest.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.cyan)
                }
                .padding()
                .background(Color(red: 0.10, green: 0.14, blue: 0.22))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3)))

                // Proceed Button
                Button {
                    // Store consent status for WatchConnectivity remote trigger
                    UserDefaults.standard.set(true, forKey: "ease_consent_ready")
                    WatchSessionManager.shared.sendStateToWatch(isRecording: false, consentCompleted: true, duration: "00:00")
                    currentStep = .recording
                } label: {
                    Text("Proceed to Recording")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasAffirmativeConsent && !participantsList.isEmpty ? Color.cyan : Color.gray.opacity(0.4))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .disabled(!hasAffirmativeConsent || participantsList.isEmpty)
            }
        }
    }

    // Step 3: Big Recording Screen
    private var recordingStep: some View {
        VStack(spacing: 36) {
            Spacer()

            Text(meetingTitle.isEmpty ? "In-Person Discussion" : meetingTitle)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("\(participantsList.count) Consented Participants")
                .font(.subheadline)
                .foregroundColor(.cyan)

            // Timer display
            Text(recorder.formattedDuration)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundColor(.white)

            // Audio Metering Visualizer
            HStack(spacing: 4) {
                ForEach(0..<16) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(recorder.isRecording ? Color.cyan : Color.gray)
                        .frame(width: 6, height: max(6, CGFloat(sin(Double(i) + recorder.elapsedTime * 4) * 20 + 24)))
                }
            }
            .frame(height: 50)

            Spacer()

            // Big Start / Stop Button
            Button {
                if recorder.isRecording {
                    let url = recorder.stopRecording()
                    recordedAudioURL = url
                    UserDefaults.standard.set(false, forKey: "ease_consent_ready")
                    WatchSessionManager.shared.sendStateToWatch(isRecording: false, consentCompleted: false, duration: recorder.formattedDuration)
                    startUpload()
                } else {
                    _ = recorder.startRecording()
                    WatchSessionManager.shared.sendStateToWatch(isRecording: true, consentCompleted: true, duration: "00:00")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.cyan)
                        .frame(width: 90, height: 90)
                        .shadow(color: (recorder.isRecording ? Color.red : Color.cyan).opacity(0.5), radius: 16)

                    Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                }
            }

            Text(recorder.isRecording ? "Tap to Stop & Process" : "Tap to Begin Recording")
                .font(.footnote)
                .foregroundColor(.gray)

            Spacer()
        }
    }

    // Step 4: Uploading & Pipeline Trigger
    private var uploadingStep: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.cyan)

            Text("Ingesting & Processing Discussion")
                .font(.headline)
                .foregroundColor(.white)

            Text("Normalizing audio, running speaker diarization, and extracting decisions...")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let err = uploadErrorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)

                Button("Retry Upload") {
                    startUpload()
                }
                .foregroundColor(.cyan)
            }
        }
    }

    // Step 5: Done
    private var doneStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Discussion Ingested!")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("The discussion is being analyzed in the background. The executive report will be ready in your project space.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button("View Discussion Space") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.cyan)
            .foregroundColor(.black)
            .cornerRadius(10)
        }
    }

    private func startUpload() {
        guard let url = recordedAudioURL, let project = selectedProject else { return }
        currentStep = .uploading
        isUploading = true
        uploadErrorMessage = nil

        Task {
            do {
                let summary = try await APIClient.shared.uploadMeeting(
                    projectId: project.id,
                    audioFileURL: url,
                    title: meetingTitle.isEmpty ? "Discussion \(Date().formatted(date: .abbreviated, time: .shortened))" : meetingTitle,
                    participants: participantsList,
                    spokenAnnouncementPlayed: consentAnnouncementPlayed
                )
                await MainActor.run {
                    createdMeetingSummary = summary
                    isUploading = false
                    currentStep = .done
                }
            } catch {
                await MainActor.run {
                    // If network fails, enqueue locally
                    OfflineRecordingQueue.shared.enqueue(
                        projectId: project.id,
                        title: meetingTitle,
                        fileURL: url,
                        participants: participantsList
                    )
                    uploadErrorMessage = "Uploaded queued for offline retry: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }
}

// Simple FlowLayout helper for participant chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: height + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
