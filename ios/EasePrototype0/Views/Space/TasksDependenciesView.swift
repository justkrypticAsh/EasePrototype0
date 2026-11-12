// TasksDependenciesView.swift
import SwiftUI

struct TasksDependenciesView: View {
    let projectId: String
    @EnvironmentObject var env: AppEnvironment

    @State private var tasks: [PrerequisiteModel] = []
    @State private var isLoading = true
    @State private var exportSuccessMessage: String?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.cyan)
            } else if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Assigned Action Items")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Tasks and prerequisites assigned to team members appear here with status tracking.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let msg = exportSuccessMessage {
                            Text(msg)
                                .font(.caption.bold())
                                .foregroundColor(.green)
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        }

                        ForEach(tasks) { task in
                            taskCard(task)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadTasks()
        }
    }

    private func taskCard(_ task: PrerequisiteModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Blocked / Unblocked Indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(task.dependsOn != nil && !task.isDone ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(task.dependsOn != nil && !task.isDone ? "BLOCKED" : "READY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(task.dependsOn != nil && !task.isDone ? .orange : .green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((task.dependsOn != nil && !task.isDone ? Color.orange : Color.green).opacity(0.15))
                .cornerRadius(4)

                Spacer()

                // Status Badge
                Text(task.status.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(task.isDone ? .green : .cyan)
            }

            Text(task.text)
                .font(.body.bold())
                .foregroundColor(.white)

            if let dep = task.dependsOn {
                HStack(alignment: .top) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Depends on: \(dep)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                // Status Toggle Button
                Button {
                    let nextStatus = task.isDone ? "open" : "done"
                    updateStatus(task: task, newStatus: nextStatus)
                } label: {
                    HStack {
                        Image(systemName: task.isDone ? "arrow.uturn.backward" : "checkmark")
                        Text(task.isDone ? "Reopen" : "Mark Done")
                    }
                    .font(.footnote.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(task.isDone ? Color.gray.opacity(0.3) : Color.green.opacity(0.2))
                    .foregroundColor(task.isDone ? .gray : .green)
                    .cornerRadius(6)
                }

                // Apple Reminders Integration via EventKit
                Button {
                    exportToReminders(task: task)
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Add to Reminders")
                    }
                    .font(.footnote.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
        .cornerRadius(10)
    }

    private func loadTasks() async {
        // Load meetings to collect prerequisites
        do {
            let meetings: [MeetingSummary] = try await APIClient.shared.request(path: "/projects/\(projectId)/meetings")
            var allPrereqs: [PrerequisiteModel] = []
            for m in meetings {
                let detail: MeetingDetailResponse = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/meetings/\(m.id)"
                )
                allPrereqs.append(contentsOf: detail.prerequisites)
            }
            await MainActor.run {
                tasks = allPrereqs
                isLoading = false
            }
        } catch {
            print("Failed to load tasks: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func updateStatus(task: PrerequisiteModel, newStatus: String) {
        Task {
            do {
                let body = try JSONEncoder().encode(["status": newStatus, "reason": "Updated from iOS Task Space"])
                let _: [String: String] = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/items/prerequisite/\(task.id)/status",
                    method: "PATCH",
                    body: body
                )
                await loadTasks()
            } catch {
                print("Failed to update status: \(error)")
            }
        }
    }

    private func exportToReminders(task: PrerequisiteModel) {
        Task {
            do {
                let notes = task.dependsOn != nil ? "EASE Prerequisite. Depends on: \(task.dependsOn!)" : "EASE Prerequisite Action Item."
                let success = try await EventKitService.shared.addReminder(title: task.text, notes: notes)
                await MainActor.run {
                    if success {
                        exportSuccessMessage = "✓ Added to Apple Reminders"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            exportSuccessMessage = nil
                        }
                    }
                }
            } catch {
                print("Failed to export reminder: \(error)")
            }
        }
    }
}
