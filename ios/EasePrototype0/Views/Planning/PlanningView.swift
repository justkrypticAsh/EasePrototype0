// PlanningView.swift
import SwiftUI

struct PlanningView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var selectedDate: Date = Date()
    @State private var showScheduleSheet: Bool = false
    @State private var selectedProjectFilter: String = "all"
    @State private var scheduledDiscussions: [ScheduledDiscussionItem] = [
        ScheduledDiscussionItem(
            id: "sched-001",
            title: "Product Launch Architecture & Blocker Review",
            projectName: "Product Launch",
            projectId: "project-product-launch",
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            durationMinutes: 45,
            attendees: ["Aarav Mehta", "Riya Sharma", "Kabir Singh"],
            notes: "Review Riya's client security architecture sign-off and unblock Kabir's migration."
        ),
        ScheduledDiscussionItem(
            id: "sched-002",
            title: "iOS Biometric Voice Vault Privacy Check",
            projectName: "Product Launch",
            projectId: "project-product-launch",
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            durationMinutes: 30,
            attendees: ["Aarav Mehta", "Neha Kapoor"],
            notes: "Final legal verification of consent audio retention policy and instant deletion."
        )
    ]

    var filteredDiscussions: [ScheduledDiscussionItem] {
        if selectedProjectFilter == "all" {
            return scheduledDiscussions
        }
        return scheduledDiscussions.filter { $0.projectId == selectedProjectFilter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                // Ambient background glows
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.easeCyan.opacity(0.12))
                            .frame(width: 260, height: 260)
                            .blur(radius: 75)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.easePurple.opacity(0.1))
                            .frame(width: 240, height: 240)
                            .blur(radius: 70)
                    }
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header & Quick Schedule Action
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Project Planning")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Schedule discussions, track deadlines & sync reminders")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showScheduleSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Schedule")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.easeCyan)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                                .shadow(color: Color.easeCyan.opacity(0.3), radius: 8, x: 0, y: 3)
                            }
                        }
                        .padding(.horizontal)

                        // Apple Calendar & Reminders Sync Status Banner
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 14))
                                .foregroundColor(.easeCyan)
                            Text("EventKit Live • Apple Calendar & Reminders Synced")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Circle()
                                .fill(Color.easeEmerald)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .glassCard(cornerRadius: 12)
                        .padding(.horizontal)

                        // Interactive Month Calendar Card
                        calendarWidget
                            .padding(.horizontal)

                        // Filter by Project
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(title: "All Projects", id: "all")
                                ForEach(env.projects) { p in
                                    filterChip(title: p.name, id: p.id)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Scheduled Upcoming Discussions
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Scheduled Discussions")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(filteredDiscussions.count) planned")
                                    .font(.system(size: 12))
                                    .foregroundColor(.easeCyan)
                            }
                            .padding(.horizontal)

                            if filteredDiscussions.isEmpty {
                                Text("No discussions scheduled for this project. Tap 'Schedule' to plan one.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(filteredDiscussions) { item in
                                        scheduledDiscussionCard(item)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Project Deadlines & Prerequisite Milestones
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Upcoming Milestone Deadlines")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                GlassStatusPill(title: "EventKit", icon: "bell.fill", color: .easeAmber)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 10) {
                                deadlineRow(
                                    title: "Client Security Architecture Sign-off",
                                    project: "Product Launch",
                                    owner: "Riya Sharma",
                                    dueDate: "In 2 days",
                                    isBlocker: true,
                                    status: "Pending Action"
                                )
                                deadlineRow(
                                    title: "PostgreSQL Sharding & Migration",
                                    project: "Product Launch",
                                    owner: "Kabir Singh",
                                    dueDate: "In 5 days",
                                    isBlocker: false,
                                    status: "Blocked by Riya"
                                )
                                deadlineRow(
                                    title: "App Store Submission Checklist",
                                    project: "Product Launch",
                                    owner: "Neha Kapoor",
                                    dueDate: "In 7 days",
                                    isBlocker: false,
                                    status: "On Track"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Planning")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScheduleSheet) {
                ScheduleDiscussionSheet { newItem in
                    scheduledDiscussions.append(newItem)
                }
            }
        }
    }

    // MARK: - Calendar Widget
    private var calendarWidget: some View {
        VStack(spacing: 12) {
            HStack {
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 14) {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
            }

            // Days of week
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }

            // 7-day strip centered on selected date
            HStack(spacing: 8) {
                ForEach(-3...3, id: \.self) { offset in
                    let dayDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
                    let isSelected = Calendar.current.isDate(dayDate, inSameDayAs: selectedDate)
                    let isToday = Calendar.current.isDateInToday(dayDate)

                    VStack(spacing: 4) {
                        Text(dayDate.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isSelected ? .black : .gray)

                        Text(dayDate.formatted(.dateTime.day()))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isSelected ? .black : .white)

                        // Activity dot
                        Circle()
                            .fill(isSelected ? Color.black : (isToday ? Color.easeCyan : Color.clear))
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.easeCyan : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedDate = dayDate
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private func filterChip(title: String, id: String) -> some View {
        let isSelected = selectedProjectFilter == id
        return Button {
            selectedProjectFilter = id
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.easeCyan : Color.white.opacity(0.08))
                .foregroundColor(isSelected ? .black : .white)
                .clipShape(Capsule())
        }
    }

    private func scheduledDiscussionCard(_ item: ScheduledDiscussionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.projectName.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.easeCyan.opacity(0.2))
                    .foregroundColor(.easeCyan)
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(item.durationMinutes)m")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.gray)
            }

            Text(item.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let notes = item.notes {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            HStack {
                HStack(spacing: -6) {
                    ForEach(item.attendees.prefix(3), id: \.self) { attendee in
                        Circle()
                            .fill(Color.easeCyan.opacity(0.4))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text(String(attendee.prefix(1)))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    }
                }

                Text(item.attendees.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Spacer()

                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.easeCyan)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    private func deadlineRow(
        title: String,
        project: String,
        owner: String,
        dueDate: String,
        isBlocker: Bool,
        status: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isBlocker ? Color.easeAmber.opacity(0.2) : Color.easeCyan.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: isBlocker ? "exclamationmark.triangle.fill" : "calendar")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isBlocker ? .easeAmber : .easeCyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(project) • Assigned to \(owner)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(dueDate)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isBlocker ? .easeAmber : .white)
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(isBlocker ? .easeAmber : .easeEmerald)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }
}
