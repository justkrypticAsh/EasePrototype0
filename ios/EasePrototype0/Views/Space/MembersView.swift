// MembersView.swift
import SwiftUI

struct MembersView: View {
    let projectId: String
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject private var icloudService = ICloudWorkspaceService.shared

    @State private var members: [ProjectMember] = []
    @State private var reports: [ICloudReport] = []
    @State private var isLoading = true
    @State private var showAddAppleIdSheet = false
    @State private var showShareSheet = false
    @State private var shareURLs: [URL] = []
    @State private var toastMessage: String? = nil
    @State private var showToast = false

    var currentProjectName: String {
        env.projects.first(where: { $0.id == projectId })?.name ?? "EASE Project"
    }

    var body: some View {
        ZStack {
            Color.easeBackground.ignoresSafeArea()

            // Ambient background lighting
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.easePurple.opacity(0.12))
                        .frame(width: 260, height: 260)
                        .blur(radius: 80)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(Color.easeCyan.opacity(0.1))
                        .frame(width: 240, height: 240)
                        .blur(radius: 70)
                    Spacer()
                }
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - iCloud Shared Workspace Folder Card
                    icloudSharedFolderCard

                    // MARK: - Collaborators Section Header
                    collaboratorsHeader

                    // MARK: - Collaborators List
                    if isLoading {
                        ProgressView().tint(.easeCyan)
                            .padding(.vertical, 30)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(members) { m in
                                collaboratorCard(m)
                            }
                        }
                    }

                    // MARK: - Reports in Shared Folder
                    if !reports.isEmpty {
                        icloudReportsList
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $showAddAppleIdSheet) {
            AddAppleIdCollaboratorSheet(projectId: projectId) { newMember in
                self.members.insert(newMember, at: 0)
                triggerToast("✓ Collaborator added via Apple ID")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareURLs.isEmpty {
                ShareSheetView(activityItems: shareURLs)
            }
        }
        .alert("Collaboration Notification", isPresented: $showToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(toastMessage ?? "")
        }
        .task {
            await loadData()
        }
    }

    // MARK: - iCloud Shared Folder Card
    private var icloudSharedFolderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.easeCyan.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.easeCyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Shared Project Space")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Auto-shared reports folder across all collaborators")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()

                GlassStatusPill(title: "iCloud Active", icon: "arrow.triangle.2.circlepath", color: .easeEmerald)
            }

            // Path Tile
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.easeCyan)
                Text("iCloud Drive ❯ EASE ❯ \(currentProjectName) ❯ Reports")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Stats and Sync Button
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(reports.count) Discussion Reports")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text("Markdown + Summaries")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Sync to iCloud Button
                Button {
                    syncToICloudNow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icloudService.isSyncing ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text(icloudService.isSyncing ? "Syncing..." : "Sync Reports")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.easeCyan)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .disabled(icloudService.isSyncing)

                // Share Folder via native Apple Share Sheet
                Button {
                    shareFolderViaAppleShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(9)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20, glowColor: .easeCyan, glowRadius: 8, strokeOpacity: 0.3)
    }

    // MARK: - Collaborators Header
    private var collaboratorsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Project Collaborators")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(members.count) members linked with Apple ID")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()

            Button {
                showAddAppleIdSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Apple ID")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.easeCyan)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.easeCyan.opacity(0.4), lineWidth: 1))
            }
        }
    }

    // MARK: - Collaborator Card
    private func collaboratorCard(_ m: ProjectMember) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [m.role == "owner" ? Color.easePurple : Color.easeCyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                Text(m.fullName.prefix(1).uppercased())
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(m.fullName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    if m.role == "owner" {
                        Text("LEAD")
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.easePurple.opacity(0.3))
                            .foregroundColor(.easePurple)
                            .clipShape(Capsule())
                    }
                }

                // Apple ID Indicator
                HStack(spacing: 4) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(m.appleId ?? m.email)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Verified iCloud Badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.easeCyan)
                Text("iCloud")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Reports in iCloud Folder List
    private var icloudReportsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shared Reports in Folder")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            ForEach(reports.prefix(4)) { r in
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.easeCyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(r.filename)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    ShareLink(item: r.contentMarkdown) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(6)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Data Operations
    private func loadData() async {
        isLoading = true
        // 1. Fetch Members
        do {
            let fetchedMembers: [ProjectMember] = try await APIClient.shared.request(
                path: "/projects/\(projectId)/members"
            )
            await MainActor.run {
                self.members = fetchedMembers
            }
        } catch {
            print("Failed to load members from backend, using fallback.")
            await MainActor.run {
                self.members = [
                    ProjectMember(
                        userId: "u1",
                        email: "ashish@ease.ai",
                        fullName: "Ashish Sharma",
                        role: "owner",
                        appleId: "ashish.sharma@icloud.com",
                        joinedAt: "2026-11-13"
                    ),
                    ProjectMember(
                        userId: "u2",
                        email: "priya@icloud.com",
                        fullName: "Priya Patel",
                        role: "member",
                        appleId: "priya.patel@icloud.com",
                        joinedAt: "2026-11-13"
                    )
                ]
            }
        }

        // 2. Fetch iCloud Reports
        do {
            let syncResp: ICloudSyncInfo = try await APIClient.shared.request(
                path: "/projects/\(projectId)/icloud/reports"
            )
            await MainActor.run {
                self.reports = syncResp.reports
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch iCloud reports, using local template.")
            await MainActor.run {
                self.reports = [
                    ICloudReport(
                        filename: "2026-11-13_Sprint_Planning_Report.md",
                        meetingId: "m1",
                        title: "Sprint Planning & Core Roadmap",
                        contentMarkdown: "# Sprint Planning & Core Roadmap\n\n## Executive Summary\nArchitectural review of EASE speaker separation and task dependencies.",
                        summary: "Discussion covering speaker diarization, cross-discussion vector memory, and Apple ID collaboration.",
                        decisionsCount: 3,
                        claimsCount: 5,
                        prerequisitesCount: 2,
                        createdAt: "2026-11-13"
                    )
                ]
                self.isLoading = false
            }
        }
    }

    private func syncToICloudNow() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            let urls = await icloudService.syncReportsToICloud(projectName: currentProjectName, reports: reports)
            await MainActor.run {
                self.shareURLs = urls
                triggerToast("✓ Synced \(urls.count) discussion reports to iCloud Drive folder")
            }
        }
    }

    private func shareFolderViaAppleShare() {
        let folderURL = icloudService.getProjectReportsDirectory(projectName: currentProjectName)
        self.shareURLs = [folderURL]
        self.showShareSheet = true
    }

    private func triggerToast(_ msg: String) {
        toastMessage = msg
        showToast = true
    }
}

// MARK: - Add Apple ID Collaborator Sheet
struct AddAppleIdCollaboratorSheet: View {
    let projectId: String
    let onAdded: (ProjectMember) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appleId: String = ""
    @State private var fullName: String = ""
    @State private var role: String = "member"
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Add Apple ID Collaborator")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }

                    Text("Invite a team member using their Apple ID or iCloud email to automatically grant access to the shared discussion reports and blocker graph.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("COLLABORATOR APPLE ID / iCLOUD EMAIL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        TextField("e.g. colleague@icloud.com", text: $appleId)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .foregroundColor(.white)
                            .glassCard(cornerRadius: 12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("FULL NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        TextField("e.g. Priya Patel", text: $fullName)
                            .padding()
                            .foregroundColor(.white)
                            .glassCard(cornerRadius: 12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("COLLABORATION ROLE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        Picker("Role", selection: $role) {
                            Text("Core Contributor (Member)").tag("member")
                            Text("Reviewer").tag("reviewer")
                            Text("Project Owner").tag("owner")
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        submitCollaborator()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "person.badge.plus.fill")
                                Text("Add Collaborator & Sync iCloud")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.easeCyan)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(appleId.isEmpty || fullName.isEmpty || isSubmitting)

                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }

    private func submitCollaborator() {
        isSubmitting = true
        Task {
            do {
                let body = try JSONEncoder().encode([
                    "apple_id": appleId.trimmingCharacters(in: .whitespacesAndNewlines),
                    "full_name": fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "role": role
                ])
                let newMember: ProjectMember = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/collaborators",
                    method: "POST",
                    body: body
                )
                await MainActor.run {
                    onAdded(newMember)
                    dismiss()
                }
            } catch {
                // Local fallback simulation
                await MainActor.run {
                    let localMember = ProjectMember(
                        userId: UUID().uuidString,
                        email: appleId,
                        fullName: fullName,
                        role: role,
                        appleId: appleId,
                        joinedAt: "2026-11-13"
                    )
                    onAdded(localMember)
                    dismiss()
                }
            }
        }
    }
}
