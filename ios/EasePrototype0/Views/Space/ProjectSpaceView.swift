// ProjectSpaceView.swift
import SwiftUI

struct ProjectSpaceView: View {
    let project: Project
    @State private var selectedTab = 0
    @State private var meetings: [MeetingSummary] = []
    @State private var isLoadingMeetings = true
    @State private var showCaptureFlow = false

    var body: some View {
        ZStack {
            Color.easeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Space Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("\(project.domain.capitalized) Space &bull; \(project.languageCode.uppercased())")
                            .font(.caption)
                            .foregroundColor(.easeCyan)
                    }
                    Spacer()
                    Button {
                        showCaptureFlow = true
                    } label: {
                        HStack {
                            Circle().fill(Color.easeRuby).frame(width: 6, height: 6)
                            Text("Capture")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.easeCyan)
                        .foregroundColor(.black)
                        .cornerRadius(20)
                    }
                }
                .padding()

                // Project Space Tabs
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tabItem {
                            Label("Overview", systemImage: "chart.bar.doc.horizontal")
                        }
                        .tag(0)

                    discussionsTab
                        .tabItem {
                            Label("Discussions", systemImage: "bubble.left.and.bubble.right")
                        }
                        .tag(1)

                    ProjectMemoryView(projectId: project.id)
                        .tabItem {
                            Label("Memory", systemImage: "brain.head.profile")
                        }
                        .tag(2)

                    TasksDependenciesView(projectId: project.id)
                        .tabItem {
                            Label("Tasks", systemImage: "checklist")
                        }
                        .tag(3)

                    BriefingView(projectId: project.id)
                        .tabItem {
                            Label("Briefing", systemImage: "headphones")
                        }
                        .tag(4)

                    MembersView(projectId: project.id)
                        .tabItem {
                            Label("Team & iCloud", systemImage: "person.2.badge.gearshape.fill")
                        }
                        .tag(5)
                }
                .tint(.cyan)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCaptureFlow) {
            CaptureFlowView()
        }
        .task {
            await loadMeetings()
        }
    }

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Stats
                HStack(spacing: 12) {
                    statCard(title: "Discussions", value: "\(meetings.count)", icon: "waveform", color: .easeCyan)
                    statCard(title: "Status", value: "Active", icon: "shield.checkered", color: .easeEmerald)
                    statCard(title: "Domain", value: project.domain.capitalized, icon: "briefcase", color: .easePurple)
                }

                // Recent Discussions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Project Discussions")
                        .font(.headline)
                        .foregroundColor(.white)

                    if meetings.isEmpty {
                        Text("No discussions recorded yet. Tap Capture above to record with explicit consent.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(meetings.prefix(3)) { m in
                            NavigationLink(destination: DiscussionDetailView(projectId: project.id, meetingId: m.id)) {
                                meetingRow(m)
                            }
                        }
                    }
                }
                .padding()
                .glassCard(cornerRadius: 16)
            }
            .padding()
        }
    }

    private var discussionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(meetings) { m in
                    NavigationLink(destination: DiscussionDetailView(projectId: project.id, meetingId: m.id)) {
                        meetingRow(m)
                    }
                }
            }
            .padding()
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(cornerRadius: 14)
    }

    private func meetingRow(_ m: MeetingSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(m.title)
                    .font(.body.bold())
                    .foregroundColor(.white)
                Text("Duration: \(Int(m.audioDurationSeconds))s")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            GlassStatusPill(
                title: m.status,
                icon: nil,
                color: m.isReady ? .easeEmerald : .easeAmber
            )
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }

    private func loadMeetings() async {
        do {
            let fetched: [MeetingSummary] = try await APIClient.shared.request(path: "/projects/\(project.id)/meetings")
            await MainActor.run {
                meetings = fetched
                isLoadingMeetings = false
            }
        } catch {
            print("Failed to load meetings: \(error)")
            await MainActor.run { isLoadingMeetings = false }
        }
    }
}
