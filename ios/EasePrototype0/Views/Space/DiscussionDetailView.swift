// DiscussionDetailView.swift
import SwiftUI

struct DiscussionDetailView: View {
    let projectId: String
    let meetingId: String

    @StateObject private var player = AudioPlayerService()
    @State private var meetingDetail: MeetingDetailResponse?
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var editingSpeaker: String?
    @State private var renamedSpeaker = ""
    @State private var shareSheetPresented = false
    @State private var shareURL: String?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.cyan)
            } else if let detail = meetingDetail {
                VStack(spacing: 0) {
                    // Audio Player Bar
                    audioPlayerHeader(detail.meeting)

                    // Sub-tabs: Transcript, Claims & Decisions, Prerequisites
                    Picker("", selection: $selectedTab) {
                        Text("Transcript").tag(0)
                        Text("Claims & Decisions").tag(1)
                        Text("Prerequisites").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    TabView(selection: $selectedTab) {
                        transcriptView(detail.transcript)
                            .tag(0)
                        claimsAndDecisionsView(detail.claims, detail.decisions)
                            .tag(1)
                        prerequisitesView(detail.prerequisites)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            } else {
                Text("Meeting details not available")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle(meetingDetail?.meeting.title ?? "Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareMeeting()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.cyan)
                }
            }
        }
        .task {
            await loadDetail()
        }
        .sheet(isPresented: $shareSheetPresented) {
            if let urlStr = shareURL, let url = URL(string: urlStr) {
                ShareSheet(items: [url])
            }
        }
    }

    private func audioPlayerHeader(_ meeting: MeetingDetail) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(String(format: "%02d:%02d / %02d:%02d",
                                Int(player.currentTime) / 60, Int(player.currentTime) % 60,
                                Int(meeting.audioDurationSeconds) / 60, Int(meeting.audioDurationSeconds) % 60))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(meeting.status.uppercased())
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(meeting.status == "ready" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(meeting.status == "ready" ? .green : .orange)
                    .cornerRadius(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(red: 0.10, green: 0.14, blue: 0.22))
        }
    }

    // 1. Transcript with Tap-to-jump & Speaker renaming
    private func transcriptView(_ segments: [TranscriptSegment]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(segments) { seg in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button {
                                editingSpeaker = seg.speakerLabel
                                renamedSpeaker = seg.speakerLabel
                            } label: {
                                Text(seg.speakerLabel)
                                    .font(.caption.bold())
                                    .foregroundColor(.cyan)
                            }

                            Text(seg.formattedTimestamp)
                                .font(.caption2)
                                .foregroundColor(.gray)

                            if seg.isLowConfidence {
                                Text("Low Conf")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(4)
                            }

                            if seg.isOverlapping {
                                Text("Overlap")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            }

                            Spacer()

                            Button {
                                player.seek(to: seg.startSeconds)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }

                        Text(seg.text)
                            .font(.body)
                            .foregroundColor(.white)

                        if let sug = seg.suggestedSpeakerLabel {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text("AI Suggestion: May be \(sug) (\(seg.reconciliationReason ?? ""))")
                                    .font(.caption2)
                                    .foregroundColor(.yellow.opacity(0.8))
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }

    // 2. Claims & Decisions with Tap-to-jump
    private func claimsAndDecisionsView(_ claims: [ClaimModel], _ decisions: [DecisionModel]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Decisions
                Text("Decisions Reached (\(decisions.count))")
                    .font(.headline)
                    .foregroundColor(.white)

                ForEach(decisions) { dec in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dec.text)
                                .font(.body.bold())
                                .foregroundColor(.white)
                            if let decider = dec.decidedBy {
                                Text("Decided by \(decider)")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }
                        Spacer()
                        Button {
                            player.seek(to: dec.startSeconds)
                        } label: {
                            Image(systemName: "play.circle")
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(8)
                }

                // Claims
                Text("Claims & Assertions (\(claims.count))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top)

                ForEach(claims) { claim in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(claim.type.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                Text(claim.speakerLabel)
                                    .font(.caption.bold())
                                    .foregroundColor(.cyan)
                            }
                            Text("\"\(claim.text)\"")
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button {
                            player.seek(to: claim.startSeconds)
                        } label: {
                            Image(systemName: "play.circle")
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }

    // 3. Prerequisites
    private func prerequisitesView(_ prereqs: [PrerequisiteModel]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(prereqs) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.text)
                                .font(.body.bold())
                                .foregroundColor(.white)
                            if let dep = p.dependsOn {
                                Text("Depends on: \(dep)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            if let owner = p.ownerMentioned {
                                Text("Owner: \(owner)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        Text(p.status.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(p.isDone ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .foregroundColor(p.isDone ? .green : .orange)
                            .cornerRadius(4)
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }

    private func loadDetail() async {
        do {
            let res: MeetingDetailResponse = try await APIClient.shared.request(
                path: "/projects/\(projectId)/meetings/\(meetingId)"
            )
            await MainActor.run {
                meetingDetail = res
                isLoading = false
            }
        } catch {
            print("Failed to load meeting detail: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func shareMeeting() {
        Task {
            do {
                let res: [String: String] = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/meetings/\(meetingId)/share",
                    method: "POST"
                )
                if let sharePath = res["share_url"] {
                    await MainActor.run {
                        shareURL = "\(APIClient.shared.baseURLString)\(sharePath)"
                        shareSheetPresented = true
                    }
                }
            } catch {
                print("Failed to share meeting: \(error)")
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
