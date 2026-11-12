// ExtractionItems.swift
import Foundation

struct ClaimModel: Codable, Identifiable {
    let id: String
    var text: String
    let speakerLabel: String
    let timestampStartMs: Int
    let timestampEndMs: Int
    let type: String
    let confidence: Double
    var status: String
    var ownerUserId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case speakerLabel = "speaker_label"
        case timestampStartMs = "timestamp_start_ms"
        case timestampEndMs = "timestamp_end_ms"
        case type
        case confidence
        case status
        case ownerUserId = "owner_user_id"
    }

    var startSeconds: Double { Double(timestampStartMs) / 1000.0 }
}

struct DecisionModel: Codable, Identifiable {
    let id: String
    var text: String
    let timestampStartMs: Int
    let timestampEndMs: Int
    let decidedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case timestampStartMs = "timestamp_start_ms"
        case timestampEndMs = "timestamp_end_ms"
        case decidedBy = "decided_by"
    }

    var startSeconds: Double { Double(timestampStartMs) / 1000.0 }
}

struct PrerequisiteModel: Codable, Identifiable {
    let id: String
    var text: String
    let dependsOn: String?
    let ownerMentioned: String?
    var ownerUserId: String?
    var status: String
    let timestampStartMs: Int
    let timestampEndMs: Int

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case dependsOn = "depends_on"
        case ownerMentioned = "owner_mentioned"
        case ownerUserId = "owner_user_id"
        case status
        case timestampStartMs = "timestamp_start_ms"
        case timestampEndMs = "timestamp_end_ms"
    }

    var startSeconds: Double { Double(timestampStartMs) / 1000.0 }
    var isDone: Bool { status.lowercased() == "done" }
    var isConfirmed: Bool { status.lowercased() == "confirmed" }
}
