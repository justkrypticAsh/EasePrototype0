// Meeting.swift
import Foundation

struct MeetingSummary: Codable, Identifiable {
    let id: String
    let projectId: String
    let title: String
    let status: String
    let audioDurationSeconds: Double
    let costAudioMinutes: Double?
    let costLlmTokens: Int?
    let failureReason: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case title
        case status
        case audioDurationSeconds = "audio_duration_seconds"
        case costAudioMinutes = "cost_audio_minutes"
        case costLlmTokens = "cost_llm_tokens"
        case failureReason = "failure_reason"
        case createdAt = "created_at"
    }

    var isReady: Bool { status.lowercased() == "ready" }
    var isFailed: Bool { status.lowercased() == "failed" }
}

struct MeetingDetailResponse: Codable {
    let meeting: MeetingDetail
    let transcript: [TranscriptSegment]
    let claims: [ClaimModel]
    let decisions: [DecisionModel]
    let prerequisites: [PrerequisiteModel]
}

struct MeetingDetail: Codable, Identifiable {
    let id: String
    let projectId: String
    let title: String
    let status: String
    let audioDurationSeconds: Double
    let summary: String?
    let failureReason: String?
    let costAudioMinutes: Double?
    let costLlmTokens: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case title
        case status
        case audioDurationSeconds = "audio_duration_seconds"
        case summary
        case failureReason = "failure_reason"
        case costAudioMinutes = "cost_audio_minutes"
        case costLlmTokens = "cost_llm_tokens"
        case createdAt = "created_at"
    }
}
