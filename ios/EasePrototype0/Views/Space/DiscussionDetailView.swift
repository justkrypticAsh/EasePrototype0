// DiscussionDetailView.swift
import SwiftUI

struct SpeakerEditTarget: Identifiable {
    let id: String
    let label: String
}

struct DiscussionDetailView: View {
    let projectId: String
    let meetingId: String

    @StateObject private var player = AudioPlayerService()
    @State private var meetingDetail: MeetingDetailResponse?
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var speakerEditTarget: SpeakerEditTarget?
    @State private var shareSheetPresented = false
    @State private var shareURL: String?
    @State private var showDecisionHistory = false

    var body: some View {
        ZStack {
            Color.easeBackground.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.easeCyan)
            } else if let detail = meetingDetail {
                VStack(spacing: 0) {
                    // Audio Player Bar
                    audioPlayerHeader(detail.meeting)

                    // Sub-tabs: Transcript, Claims & Decisions, Prerequisites
                    Picker("", selection: $selectedTab) {
                        Text("Transcript").tag(0)
                        Text("Decisions & Claims").tag(1)
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
        .navigationTitle(meetingDetail?.meeting.title ?? "Discussion Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareMeeting()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.easeCyan)
                }
            }
        }
        .task {
            await loadDetail()
        }
        .sheet(item: $speakerEditTarget) { target in
            SpeakerNameEditSheet(
                currentSpeakerLabel: target.label,
                projectId: projectId,
                meetingId: meetingId
            ) { newName, applyGlobally in
                renameSpeakerLocal(oldLabel: target.label, newLabel: newName)
            }
        }
        .sheet(isPresented: $showDecisionHistory) {
            DecisionHistoryView(projectId: projectId)
        }
        .sheet(isPresented: $shareSheetPresented) {
            if let urlStr = shareURL, let url = URL(string: urlStr) {
                ShareSheetView(activityItems: [url])
            } else {
                ShareSheetView(activityItems: ["EASE Discussion: \(meetingDetail?.meeting.title ?? "Project Discussion")"])
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
                        .font(.system(size: 38))
                        .foregroundColor(.easeCyan)
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

                GlassStatusPill(
                    title: meeting.status.capitalized,
                    icon: meeting.status == "ready" ? "checkmark.circle.fill" : "hourglass",
                    color: meeting.status == "ready" ? .easeEmerald : .easeAmber
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 14)
            .padding(.horizontal)
            .padding(.top, 6)
        }
    }

    // 1. Transcript with Tap-to-jump & Speaker renaming
    private func transcriptView(_ segments: [TranscriptSegment]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(segments) { seg in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button {
                                speakerEditTarget = SpeakerEditTarget(id: seg.id, label: seg.speakerLabel)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(seg.speakerLabel)
                                        .font(.caption.bold())
                                        .foregroundColor(.easeCyan)
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                            }

                            Text(seg.formattedTimestamp)
                                .font(.caption2)
                                .foregroundColor(.gray)

                            if seg.isLowConfidence {
                                Text("Low Conf")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.easeAmber.opacity(0.2))
                                    .foregroundColor(.easeAmber)
                                    .cornerRadius(4)
                            }

                            if seg.isOverlapping {
                                Text("Overlap")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.easeRuby.opacity(0.2))
                                    .foregroundColor(.easeRuby)
                                    .cornerRadius(4)
                            }

                            Spacer()

                            Button {
                                player.seek(to: seg.startSeconds)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "play.circle.fill")
                                    Text("Jump")
                                }
                                .font(.caption2.bold())
                                .foregroundColor(.easeCyan)
                            }
                        }

                        Text(seg.text)
                            .font(.system(size: 14))
                            .foregroundColor(.white)

                        if let sug = seg.suggestedSpeakerLabel {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption2)
                                    .foregroundColor(.easeAmber)
                                Text("AI Suggestion: May be \(sug) (\(seg.reconciliationReason ?? ""))")
                                    .font(.caption2)
                                    .foregroundColor(.easeAmber.opacity(0.9))
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // 2. Claims & Decisions with Tap-to-jump & Decision History trigger
    private func claimsAndDecisionsView(_ claims: [ClaimModel], _ decisions: [DecisionModel]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Decisions Header with History Button
                HStack {
                    Text("Decisions Reached (\(decisions.count))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        showDecisionHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Decision History")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.easeCyan)
                    }
                }

                ForEach(decisions) { dec in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dec.text)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            if let decider = dec.decidedBy {
                                Text("Decided by \(decider)")
                                    .font(.caption)
                                    .foregroundColor(.easeCyan)
                            }
                        }
                        Spacer()
                        Button {
                            player.seek(to: dec.startSeconds)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundColor(.easeCyan)
                        }
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 14, glowColor: .easeCyan, glowRadius: 2)
                }

                // Claims
                Text("Claims & Assertions (\(claims.count))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 10)

                ForEach(claims) { claim in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(claim.type.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.easePurple.opacity(0.2))
                                    .foregroundColor(.easePurple)
                                    .clipShape(Capsule())

                                Text(claim.speakerLabel)
                                    .font(.caption.bold())
                                    .foregroundColor(.easeCyan)
                            }
                            Text("\"\(claim.text)\"")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button {
                            player.seek(to: claim.startSeconds)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundColor(.easeCyan)
                        }
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
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
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            if let dep = p.dependsOn {
                                Text("Depends on: \(dep)")
                                    .font(.caption)
                                    .foregroundColor(.easeAmber)
                            }
                            if let owner = p.ownerMentioned {
                                Text("Owner: \(owner)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        GlassStatusPill(
                            title: p.isDone ? "Done" : "Open",
                            icon: p.isDone ? "checkmark" : "clock",
                            color: p.isDone ? .easeEmerald : .easeAmber
                        )
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func renameSpeakerLocal(oldLabel: String, newLabel: String) {
        guard var current = meetingDetail else { return }
        var updatedSegments: [TranscriptSegment] = []
        for seg in current.transcript {
            if seg.speakerLabel == oldLabel {
                let updated = TranscriptSegment(
                    id: seg.id,
                    speakerLabel: newLabel,
                    startMs: seg.startMs,
                    endMs: seg.endMs,
                    text: seg.text,
                    confidence: seg.confidence,
                    isLowConfidence: seg.isLowConfidence,
                    isOverlapping: seg.isOverlapping,
                    suggestedSpeakerLabel: nil,
                    reconciliationReason: nil
                )
                updatedSegments.append(updated)
            } else {
                updatedSegments.append(seg)
            }
        }
        current.transcript = updatedSegments
        meetingDetail = current
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
            print("Backend unreachable, providing rich demo meeting detail: \(error)")
            await MainActor.run {
                provideDemoMeetingDetail()
                isLoading = false
            }
        }
    }

    private func provideDemoMeetingDetail() {
        meetingDetail = MeetingDetailResponse(
            meeting: MeetingDetail(
                id: meetingId,
                projectId: projectId,
                title: "Product Launch Architecture & Scope",
                status: "ready",
                audioDurationSeconds: 480.0,
                summary: "Approved Gemini Flash 1.5 for sub-1.2s discussion intelligence and enforced AES-256 local biometric voice vault on iOS.",
                failureReason: nil,
                costAudioMinutes: 8.0,
                costLlmTokens: 1820,
                createdAt: "2026-11-13T14:30:00Z"
            ),
            transcript: [
                TranscriptSegment(
                    id: "seg-001",
                    speakerLabel: "Aarav Mehta",
                    startMs: 0,
                    endMs: 14000,
                    text: "Welcome team. Let's align on the Q1 launch deliverables, AI stack, and dependencies.",
                    confidence: 0.98,
                    isLowConfidence: false,
                    isOverlapping: false,
                    suggestedSpeakerLabel: nil,
                    reconciliationReason: nil
                ),
                TranscriptSegment(
                    id: "seg-002",
                    speakerLabel: "Riya Sharma",
                    startMs: 14200,
                    endMs: 32000,
                    text: "Gemini Flash benchmarks show consistent 1.1s round-trip response time, well within our 1.2s SLA.",
                    confidence: 0.96,
                    isLowConfidence: false,
                    isOverlapping: false,
                    suggestedSpeakerLabel: nil,
                    reconciliationReason: nil
                ),
                TranscriptSegment(
                    id: "seg-003",
                    speakerLabel: "Kabir Singh",
                    startMs: 32200,
                    endMs: 55000,
                    text: "I'm ready for the database migration, but I need Riya to sign off on the client security architecture before touching production.",
                    confidence: 0.94,
                    isLowConfidence: false,
                    isOverlapping: false,
                    suggestedSpeakerLabel: nil,
                    reconciliationReason: nil
                ),
                TranscriptSegment(
                    id: "seg-004",
                    speakerLabel: "Aarav Mehta",
                    startMs: 55200,
                    endMs: 75000,
                    text: "Agreed. Let's record that blocker: Kabir is blocked until Riya delivers the security sign-off.",
                    confidence: 0.97,
                    isLowConfidence: false,
                    isOverlapping: false,
                    suggestedSpeakerLabel: nil,
                    reconciliationReason: nil
                )
            ],
            claims: [
                ClaimModel(
                    id: "claim-001",
                    text: "Gemini Flash meets 1.2s round-trip latency SLA",
                    speakerLabel: "Riya Sharma",
                    timestampStartMs: 14200,
                    timestampEndMs: 32000,
                    type: "fact_claim",
                    confidence: 0.98,
                    status: "confirmed"
                ),
                ClaimModel(
                    id: "claim-002",
                    text: "Production database sharding requires 48 hours migration window",
                    speakerLabel: "Kabir Singh",
                    timestampStartMs: 32200,
                    timestampEndMs: 55000,
                    type: "estimate",
                    confidence: 0.91,
                    status: "open"
                )
            ],
            decisions: [
                DecisionModel(
                    id: "dec-001",
                    text: "Adopt Gemini Flash 1.5 for sub-1.2s discussion intelligence",
                    timestampStartMs: 14200,
                    timestampEndMs: 32000,
                    decidedBy: "Aarav Mehta"
                ),
                DecisionModel(
                    id: "dec-002",
                    text: "Enforce AES-256 encrypted local biometric voice vault on iOS",
                    timestampStartMs: 55200,
                    timestampEndMs: 75000,
                    decidedBy: "Aarav Mehta"
                )
            ],
            prerequisites: [
                PrerequisiteModel(
                    id: "prereq-001",
                    text: "Finalize Client Security Architecture & Sign-off",
                    dependsOn: nil,
                    ownerMentioned: "Riya Sharma",
                    status: "open",
                    timestampStartMs: 32200,
                    timestampEndMs: 55000
                ),
                PrerequisiteModel(
                    id: "prereq-002",
                    text: "Deploy Production PostgreSQL Sharding & Migration",
                    dependsOn: "Finalize Client Security Architecture & Sign-off",
                    ownerMentioned: "Kabir Singh",
                    status: "open",
                    timestampStartMs: 32200,
                    timestampEndMs: 55000
                )
            ]
        )
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
                await MainActor.run {
                    shareURL = nil
                    shareSheetPresented = true
                }
            }
        }
    }
}
