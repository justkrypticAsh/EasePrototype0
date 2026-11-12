// MemoryLink.swift
import Foundation

struct MemoryLink: Codable, Identifiable {
    let id: String
    let projectId: String
    let oldItemId: String
    let oldItemType: String
    let newItemId: String
    let newItemType: String
    let relation: String
    let shortReason: String
    let similarity: Double
    let judgeConfidence: Double
    let needsReview: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case oldItemId = "old_item_id"
        case oldItemType = "old_item_type"
        case newItemId = "new_item_id"
        case newItemType = "new_item_type"
        case relation
        case shortReason = "short_reason"
        case similarity
        case judgeConfidence = "judge_confidence"
        case needsReview = "needs_review"
        case createdAt = "created_at"
    }

    var relationColorHex: String {
        switch relation.uppercased() {
        case "CONFIRMS": return "#10B981" // green
        case "CONTRADICTS": return "#EF4444" // red
        case "UPDATES": return "#3B82F6" // blue
        case "RESOLVES_PREREQUISITE": return "#8B5CF6" // purple
        default: return "#6B7280" // gray
        }
    }
}
