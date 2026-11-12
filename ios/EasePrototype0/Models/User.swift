// User.swift
import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let fullName: String
    let isActive: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let userId: String
    let email: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case userId = "user_id"
        case email
        case fullName = "full_name"
    }
}
