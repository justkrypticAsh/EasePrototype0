// EventKitService.swift
import Foundation
import EventKit

final class EventKitService {
    static let shared = EventKitService()
    private let eventStore = EKEventStore()

    private init() {}

    func addReminder(title: String, notes: String?, dueDate: Date? = nil) async throws -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await eventStore.requestFullAccessToReminders()
        } else {
            granted = try await eventStore.requestAccess(to: .reminder)
        }

        guard granted else { return false }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let due = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }

        try eventStore.save(reminder, commit: true)
        return true
    }

    func addCalendarEvent(title: String, startDate: Date, endDate: Date, notes: String?) async throws -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = try await eventStore.requestAccess(to: .event)
        }

        guard granted else { return false }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        return true
    }
}
