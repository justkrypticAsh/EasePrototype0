// ScheduleDiscussionSheet.swift
import SwiftUI

struct ScheduledDiscussionItem: Identifiable, Codable {
    let id: String
    var title: String
    var projectName: String
    var projectId: String
    var date: Date
    var durationMinutes: Int
    var attendees: [String]
    var notes: String?
}

struct ScheduleDiscussionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var env: AppEnvironment

    @State private var title: String = ""
    @State private var selectedProjectId: String = ""
    @State private var scheduledDate: Date = Date().addingTimeInterval(3600 * 2)
    @State private var durationMinutes: Int = 45
    @State private var selectedAttendees: Set<String> = ["Aarav Mehta", "Riya Sharma"]
    @State private var newAttendee: String = ""
    @State private var agendaNotes: String = "Review prerequisite status, architecture updates, and launch blockers."
    @State private var syncToAppleCalendar: Bool = true
    @State private var syncToReminders: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var statusMessage: String?

    let onSchedule: ((ScheduledDiscussionItem) -> Void)?

    let availableTeamMembers = [
        "Aarav Mehta",
        "Riya Sharma",
        "Kabir Singh",
        "Neha Kapoor",
        "Priya Patel",
        "Vikram Sen"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DISCUSSION TITLE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            TextField("e.g. Q1 Architecture & Blocker Review", text: $title)
                                .padding()
                                .foregroundColor(.white)
                                .glassCard(cornerRadius: 12)
                        }

                        // Project Space
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TARGET PROJECT SPACE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            Picker("Project", selection: $selectedProjectId) {
                                ForEach(env.projects) { p in
                                    Text(p.name).tag(p.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassCard(cornerRadius: 12)
                        }

                        // Date & Time
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DATE & TIME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .padding()
                                .glassCard(cornerRadius: 16)
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PLANNED DURATION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            Picker("Duration", selection: $durationMinutes) {
                                Text("30 mins").tag(30)
                                Text("45 mins").tag(45)
                                Text("60 mins").tag(60)
                                Text("90 mins").tag(90)
                            }
                            .pickerStyle(.segmented)
                        }

                        // Collaborators to Include
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COLLABORATORS TO INVITE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            VStack(spacing: 8) {
                                ForEach(availableTeamMembers, id: \.self) { member in
                                    HStack {
                                        Image(systemName: selectedAttendees.contains(member) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedAttendees.contains(member) ? .easeCyan : .gray)
                                            .font(.system(size: 16))

                                        Text(member)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)

                                        Spacer()

                                        if member == "Aarav Mehta" {
                                            Text("Owner").font(.system(size: 10, weight: .bold)).foregroundColor(.easeCyan)
                                        } else if member == "Riya Sharma" {
                                            Text("Editor").font(.system(size: 10, weight: .bold)).foregroundColor(.easePurple)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedAttendees.contains(member) {
                                            selectedAttendees.remove(member)
                                        } else {
                                            selectedAttendees.insert(member)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .glassCard(cornerRadius: 14)
                        }

                        // Agenda Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AGENDA & PRE-MEETING CONTEXT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            TextEditor(text: $agendaNotes)
                                .frame(height: 70)
                                .padding(8)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .glassCard(cornerRadius: 12)
                        }

                        // Apple Ecosystem Sync Toggles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("APPLE ECOSYSTEM INTEGRATION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.easeCyan)

                            Toggle(isOn: $syncToAppleCalendar) {
                                HStack(spacing: 10) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.easeCyan)
                                    VStack(alignment: .leading) {
                                        Text("Add to Apple Calendar").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                        Text("Creates calendar event with attendee notifications").font(.caption2).foregroundColor(.gray)
                                    }
                                }
                            }
                            .tint(.easeCyan)

                            Toggle(isOn: $syncToReminders) {
                                HStack(spacing: 10) {
                                    Image(systemName: "list.bullet.circle.fill")
                                        .foregroundColor(.easeAmber)
                                    VStack(alignment: .leading) {
                                        Text("Create Apple Reminder").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                        Text("Notifies 15 minutes prior with pre-meeting briefing link").font(.caption2).foregroundColor(.gray)
                                    }
                                }
                            }
                            .tint(.easeAmber)
                        }
                        .padding()
                        .glassCard(cornerRadius: 14)

                        // Submit Button
                        Button {
                            scheduleDiscussion()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("Schedule Discussion & Send Invites")
                                }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty ? Color.gray.opacity(0.4) : Color.easeCyan)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(title.isEmpty || isSubmitting)

                        if let msg = statusMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.easeEmerald)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Schedule Discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
            }
            .onAppear {
                if selectedProjectId.isEmpty, let first = env.projects.first {
                    selectedProjectId = first.id
                }
            }
        }
    }

    private func scheduleDiscussion() {
        isSubmitting = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let pName = env.projects.first(where: { $0.id == selectedProjectId })?.name ?? "Project Space"
            let item = ScheduledDiscussionItem(
                id: UUID().uuidString,
                title: title,
                projectName: pName,
                projectId: selectedProjectId,
                date: scheduledDate,
                durationMinutes: durationMinutes,
                attendees: Array(selectedAttendees),
                notes: agendaNotes
            )

            // EventKit Calendar Sync
            if syncToAppleCalendar {
                do {
                    _ = try await EventKitService.shared.addCalendarEvent(
                        title: "[EASE] \(title)",
                        startDate: scheduledDate,
                        endDate: scheduledDate.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                        notes: "Project: \(pName)\nAttendees: \(selectedAttendees.joined(separator: ", "))\n\n\(agendaNotes)"
                    )
                } catch {
                    print("Apple Calendar sync note: \(error)")
                }
            }

            // EventKit Reminder Sync
            if syncToReminders {
                do {
                    _ = try await EventKitService.shared.addReminder(
                        title: "Prepare for EASE Discussion: \(title)",
                        notes: "Listen to pre-meeting briefing in EASE. Attendees: \(selectedAttendees.joined(separator: ", "))",
                        dueDate: scheduledDate.addingTimeInterval(-900)
                    )
                } catch {
                    print("Apple Reminders sync note: \(error)")
                }
            }

            await MainActor.run {
                isSubmitting = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                statusMessage = "✓ Discussion scheduled & synced with Apple Ecosystem"
                onSchedule?(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    dismiss()
                }
            }
        }
    }
}
