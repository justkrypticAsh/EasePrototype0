// Project.swift
import Foundation

struct Project: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var domain: String
    var languageCode: String
    var recordingPolicyText: String
    var role: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case domain
        case languageCode = "language_code"
        case recordingPolicyText = "recording_policy_text"
        case role
        case createdAt = "created_at"
    }
}

struct ProjectMember: Codable, Identifiable {
    var id: String { userId }
    let userId: String
    let email: String
    let fullName: String
    let role: String
    let joinedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case fullName = "full_name"
        case role
        case joinedAt = "joined_at"
    }
}
