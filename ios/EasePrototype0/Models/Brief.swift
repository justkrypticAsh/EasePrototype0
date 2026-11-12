// Brief.swift
import Foundation

struct BriefResponse: Codable {
    let projectId: String
    let userId: String
    let spokenScript: String
    let generatedAt: String?
    let latestDecisionsCount: Int
    let pendingPrerequisitesCount: Int
    let assignedTasksCount: Int

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case userId = "user_id"
        case spokenScript = "spoken_script"
        case generatedAt = "generated_at"
        case latestDecisionsCount = "latest_decisions_count"
        case pendingPrerequisitesCount = "pending_prerequisites_count"
        case assignedTasksCount = "assigned_tasks_count"
    }
}

struct CitationSource: Codable, Identifiable {
    var id: String { "\(meetingId)_\(timestampStartMs)" }
    let meetingId: String
    let meetingTitle: String
    let timestampStartMs: Int
    let timestampEndMs: Int
    let quote: String

    enum CodingKeys: String, CodingKey {
        case meetingId = "meeting_id"
        case meetingTitle = "meeting_title"
        case timestampStartMs = "timestamp_start_ms"
        case timestampEndMs = "timestamp_end_ms"
        case quote
    }

    var startSeconds: Double { Double(timestampStartMs) / 1000.0 }
}

struct SearchAnswerResponse: Codable {
    let query: String
    let answer: String
    let citations: [CitationSource]
}
