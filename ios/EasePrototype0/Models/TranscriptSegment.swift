// TranscriptSegment.swift
import Foundation

struct TranscriptSegment: Codable, Identifiable {
    let id: String
    var speakerLabel: String
    let startMs: Int
    let endMs: Int
    let text: String
    let confidence: Double
    let isLowConfidence: Bool
    let isOverlapping: Bool
    let suggestedSpeakerLabel: String?
    let reconciliationReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case speakerLabel = "speaker_label"
        case startMs = "start_ms"
        case endMs = "end_ms"
        case text
        case confidence
        case isLowConfidence = "is_low_confidence"
        case isOverlapping = "is_overlapping"
        case suggestedSpeakerLabel = "suggested_speaker_label"
        case reconciliationReason = "reconciliation_reason"
    }

    var startSeconds: Double {
        Double(startMs) / 1000.0
    }

    var endSeconds: Double {
        Double(endMs) / 1000.0
    }

    var formattedTimestamp: String {
        let minutes = startMs / 60000
        let seconds = (startMs % 60000) / 1000
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
