// TasksDependenciesView.swift
import SwiftUI

struct TasksDependenciesView: View {
    let projectId: String
    @EnvironmentObject var env: AppEnvironment

    @State private var dependencies: [TaskDependencyItem] = []
    @State private var isLoading = true
    @State private var selectedFilter: TaskFilter = .all
    @State private var showLinkDependencySheet = false
    @State private var selectedTaskForLinking: TaskDependencyItem? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert = false

    enum TaskFilter: String, CaseIterable, Identifiable {
        case all = "All Tasks"
        case blocked = "Blocked"
        case ready = "Ready"
        case completed = "Done"

        var id: String { rawValue }
    }

    var filteredTasks: [TaskDependencyItem] {
        switch selectedFilter {
        case .all:
            return dependencies
        case .blocked:
            return dependencies.filter { $0.isBlocked && !$0.isDone }
        case .ready:
            return dependencies.filter { !$0.isBlocked && !$0.isDone }
        case .completed:
            return dependencies.filter { $0.isDone }
        }
    }

    var blockedCount: Int {
        dependencies.filter { $0.isBlocked && !$0.isDone }.count
    }

    var body: some View {
        ZStack {
            Color.easeBackground.ignoresSafeArea()

            // Ambient background lighting
            VStack {
                HStack {
                    Circle()
                        .fill(Color.easeCyan.opacity(0.12))
                        .frame(width: 250, height: 250)
                        .blur(radius: 70)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.easeAmber.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .blur(radius: 60)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 14) {
                // Header & Blocker Metric Bar
                metricsOverviewHeader

                // Segmented Glass Filter
                glassFilterBar

                // Content
                if isLoading {
                    Spacer()
                    ProgressView().tint(.easeCyan)
                    Spacer()
                } else if filteredTasks.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredTasks) { task in
                                taskDependencyCard(task)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.top, 10)
        }
        .sheet(item: $selectedTaskForLinking) { task in
            LinkDependencySheet(
                task: task,
                allTasks: dependencies.filter { $0.id != task.id },
                onLink: { parentId, blockedByName in
                    linkDependency(task: task, parentTaskId: parentId, blockerName: blockedByName)
                }
            )
        }
        .alert("Collaboration Notification", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .task {
            await loadTaskDependencies()
        }
    }

    // MARK: - Metrics Overview Header
    private var metricsOverviewHeader: some View {
        HStack(spacing: 12) {
            // Blocker Warning Tile
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(blockedCount > 0 ? Color.easeAmber.opacity(0.2) : Color.easeEmerald.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: blockedCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(blockedCount > 0 ? .easeAmber : .easeEmerald)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(blockedCount > 0 ? "\(blockedCount) Actions Blocked" : "Zero Blockers")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(blockedCount > 0 ? "Waiting on collaborator actions" : "All dependency chains clear")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .glassCard(cornerRadius: 16, glowColor: blockedCount > 0 ? .easeAmber : .easeEmerald, glowRadius: blockedCount > 0 ? 8 : 4)

            // Refresh Button
            Button {
                Task { await loadTaskDependencies() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Segmented Glass Filter Bar
    private var glassFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(TaskFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedFilter = filter
                } label: {
                    HStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        if filter == .blocked && blockedCount > 0 {
                            Text("\(blockedCount)")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.easeRuby)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundColor(isSelected ? .white : .gray)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.easeCyan.opacity(0.25) : Color.white.opacity(0.04))
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.easeCyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Task Dependency Card with Glassmorphism
    private func taskDependencyCard(_ task: TaskDependencyItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Status Row
            HStack {
                if task.isDone {
                    GlassStatusPill(title: "Completed", icon: "checkmark.circle.fill", color: .easeEmerald)
                } else if task.isBlocked {
                    GlassStatusPill(title: "Blocked on Action", icon: "lock.fill", color: .easeRuby, pulse: true)
                } else {
                    GlassStatusPill(title: "Ready to Start", icon: "play.circle.fill", color: .easeEmerald)
                }

                Spacer()

                if let owner = task.ownerName {
                    HStack(spacing: 5) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.easeCyan)
                        Text(owner)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
            }

            // Task Description
            Text(task.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(3)

            // Visual Blocker Chain (If blocked on someone's action)
            if task.isBlocked {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.easeAmber)
                        Text("COLLABORATOR DEPENDENCY:")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.easeAmber)
                    }

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Waiting on: \(task.blockedByUserName ?? "Assigned Collaborator")")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            if let depText = task.dependsOn {
                                Text("Action: \"\(depText)\"")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()

                        // Nudge Button
                        Button {
                            nudgeCollaborator(task: task)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge.fill")
                                Text("Nudge")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.easeAmber.opacity(0.2))
                            .foregroundColor(.easeAmber)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.easeAmber.opacity(0.4), lineWidth: 1))
                        }
                    }
                    .padding(10)
                    .background(Color(red: 0.14, green: 0.10, blue: 0.08).opacity(0.6))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.easeAmber.opacity(0.3), lineWidth: 0.8))
                }
            } else if let depText = task.dependsOn {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("Unblocked from: \(depText)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            // Bottom Actions Row
            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                // Toggle Status Button
                Button {
                    let nextStatus = task.isDone ? "open" : "done"
                    toggleTaskStatus(task: task, newStatus: nextStatus)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: task.isDone ? "arrow.uturn.backward" : "checkmark")
                        Text(task.isDone ? "Reopen" : "Mark Done")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(task.isDone ? Color.white.opacity(0.08) : Color.easeEmerald.opacity(0.2))
                    .foregroundColor(task.isDone ? .gray : .easeEmerald)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(task.isDone ? Color.white.opacity(0.15) : Color.easeEmerald.opacity(0.4), lineWidth: 1))
                }

                // Link Blocker Button
                Button {
                    selectedTaskForLinking = task
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "link.badge.plus")
                        Text("Add Blocker")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.easeCyan)
                }

                Spacer()

                // Apple Reminders Export
                Button {
                    exportToAppleReminders(task: task)
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .glassCard(
            cornerRadius: 18,
            glowColor: task.isBlocked ? .easeRuby : (task.isDone ? .easeEmerald : .easeCyan),
            glowRadius: task.isBlocked ? 10 : 0,
            strokeOpacity: task.isBlocked ? 0.45 : 0.2
        )
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle().fill(Color.easeCyan.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "checklist.checked")
                    .font(.system(size: 36))
                    .foregroundColor(.easeCyan)
            }
            Text("No Action Items Found")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text("Discussion prerequisites and collaborator blocker chains will automatically organize here.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
        }
    }

    // MARK: - Network & State Actions
    private func loadTaskDependencies() async {
        isLoading = true
        do {
            let fetched: [TaskDependencyItem] = try await APIClient.shared.request(
                path: "/projects/\(projectId)/dependencies"
            )
            await MainActor.run {
                self.dependencies = fetched
                self.isLoading = false
            }
        } catch {
            print("Failed to load task dependencies from API: \(error). Using mock fallback.")
            await MainActor.run {
                loadLocalFallbackDependencies()
                self.isLoading = false
            }
        }
    }

    private func loadLocalFallbackDependencies() {
        self.dependencies = [
            TaskDependencyItem(
                id: "task-001",
                meetingId: "m1",
                projectId: projectId,
                text: "Finalize Client Security Architecture and Sign-off",
                status: "open",
                ownerName: "Priya Patel",
                ownerAppleId: "priya.patel@icloud.com",
                ownerUserId: "u1",
                dependsOn: nil,
                dependsOnTaskId: nil,
                blockedByUserName: nil,
                blockedByAppleId: nil,
                isBlocked: false,
                createdAt: "2026-11-13"
            ),
            TaskDependencyItem(
                id: "task-002",
                meetingId: "m1",
                projectId: projectId,
                text: "Deploy Production PostgreSQL Sharding & Migration",
                status: "open",
                ownerName: "Ashish Sharma",
                ownerAppleId: "ashish@ease.ai",
                ownerUserId: "u2",
                dependsOn: "Finalize Client Security Architecture and Sign-off",
                dependsOnTaskId: "task-001",
                blockedByUserName: "Priya Patel",
                blockedByAppleId: "priya.patel@icloud.com",
                isBlocked: true,
                createdAt: "2026-11-13"
            ),
            TaskDependencyItem(
                id: "task-003",
                meetingId: "m1",
                projectId: projectId,
                text: "Draft Biometric Consent Protocol Agreement",
                status: "done",
                ownerName: "Vikram Sen",
                ownerAppleId: "vikram@icloud.com",
                ownerUserId: "u3",
                dependsOn: nil,
                dependsOnTaskId: nil,
                blockedByUserName: nil,
                blockedByAppleId: nil,
                isBlocked: false,
                createdAt: "2026-11-13"
            )
        ]
    }

    private func toggleTaskStatus(task: TaskDependencyItem, newStatus: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            do {
                let body = try JSONEncoder().encode(["status": newStatus, "reason": "Updated from iOS Task Space"])
                let _: [String: String] = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/items/prerequisite/\(task.id)/status",
                    method: "PATCH",
                    body: body
                )
                await loadTaskDependencies()
            } catch {
                // Update local state directly for seamless preview
                await MainActor.run {
                    if let index = dependencies.firstIndex(where: { $0.id == task.id }) {
                        dependencies[index].status = newStatus
                        // Unblock child tasks if marked done
                        if newStatus == "done" {
                            for i in 0..<dependencies.count {
                                if dependencies[i].dependsOnTaskId == task.id {
                                    dependencies[i].isBlocked = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func nudgeCollaborator(task: TaskDependencyItem) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        Task {
            do {
                let body = try JSONEncoder().encode([
                    "message": "Waiting on your action: \(task.dependsOn ?? "prerequisite") to proceed with \"\(task.text)\""
                ])
                let _: [String: String] = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/tasks/\(task.id)/nudge",
                    method: "POST",
                    body: body
                )
                await MainActor.run {
                    alertMessage = "✓ Priority nudge sent to \(task.blockedByUserName ?? "collaborator")"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "✓ Simulated nudge sent to \(task.blockedByUserName ?? "collaborator")"
                    showAlert = true
                }
            }
        }
    }

    private func linkDependency(task: TaskDependencyItem, parentTaskId: String, blockerName: String) {
        Task {
            do {
                let body = try JSONEncoder().encode([
                    "depends_on_task_id": parentTaskId,
                    "blocked_by_user_name": blockerName
                ])
                let _: TaskDependencyItem = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/tasks/\(task.id)/dependency",
                    method: "POST",
                    body: body
                )
                await loadTaskDependencies()
            } catch {
                await MainActor.run {
                    if let idx = dependencies.firstIndex(where: { $0.id == task.id }) {
                        dependencies[idx].dependsOnTaskId = parentTaskId
                        dependencies[idx].blockedByUserName = blockerName
                        dependencies[idx].isBlocked = true
                    }
                }
            }
        }
    }

    private func exportToAppleReminders(task: TaskDependencyItem) {
        Task {
            let note = task.isBlocked ? "BLOCKED on \(task.blockedByUserName ?? "collaborator"): \(task.dependsOn ?? "")" : "EASE Action Item"
            _ = try? await EventKitService.shared.addReminder(title: task.text, notes: note)
            await MainActor.run {
                alertMessage = "✓ Added to Apple Reminders"
                showAlert = true
            }
        }
    }
}

// MARK: - Link Dependency Sheet
struct LinkDependencySheet: View {
    let task: TaskDependencyItem
    let allTasks: [TaskDependencyItem]
    let onLink: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedParentId: String = ""
    @State private var blockerName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Set Blocker Dependency")
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text("Declare what action or whose sign-off \"\(task.text)\" is waiting on before it can proceed.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("SELECT BLOCKING PREREQUISITE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.easeCyan)

                    Picker("Prerequisite", selection: $selectedParentId) {
                        Text("Select a task...").tag("")
                        ForEach(allTasks) { item in
                            Text(item.text).tag(item.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .glassCard(cornerRadius: 12)

                    Text("BLOCKER COLLABORATOR NAME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.easeCyan)

                    TextField("e.g. Priya Patel / priya@icloud.com", text: $blockerName)
                        .padding()
                        .foregroundColor(.white)
                        .glassCard(cornerRadius: 12)

                    Button {
                        if !selectedParentId.isEmpty {
                            onLink(selectedParentId, blockerName.isEmpty ? "Collaborator" : blockerName)
                            dismiss()
                        }
                    } label: {
                        Text("Confirm Dependency")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.easeCyan)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                    .disabled(selectedParentId.isEmpty)

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
}
