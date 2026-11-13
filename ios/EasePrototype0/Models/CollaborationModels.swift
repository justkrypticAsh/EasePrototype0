// CollaborationModels.swift
import Foundation

struct TaskDependencyItem: Codable, Identifiable, Hashable {
    let id: String
    let meetingId: String
    let projectId: String
    var text: String
    var status: String // open | in_progress | confirmed | done
    var ownerName: String?
    var ownerAppleId: String?
    var ownerUserId: String?
    var dependsOn: String?
    var dependsOnTaskId: String?
    var blockedByUserName: String?
    var blockedByAppleId: String?
    var isBlocked: Bool
    let createdAt: String

    var isDone: Bool {
        status.lowercased() == "done"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case meetingId = "meeting_id"
        case projectId = "project_id"
        case text
        case status
        case ownerName = "owner_name"
        case ownerAppleId = "owner_apple_id"
        case ownerUserId = "owner_user_id"
        case dependsOn = "depends_on"
        case dependsOnTaskId = "depends_on_task_id"
        case blockedByUserName = "blocked_by_user_name"
        case blockedByAppleId = "blocked_by_apple_id"
        case isBlocked = "is_blocked"
        case createdAt = "created_at"
    }
}

struct ICloudReport: Codable, Identifiable, Hashable {
    var id: String { meetingId }
    let filename: String
    let meetingId: String
    let title: String
    let contentMarkdown: String
    let summary: String
    let decisionsCount: Int
    let claimsCount: Int
    let prerequisitesCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case filename
        case meetingId = "meeting_id"
        case title
        case contentMarkdown = "content_markdown"
        case summary
        case decisionsCount = "decisions_count"
        case claimsCount = "claims_count"
        case prerequisitesCount = "prerequisites_count"
        case createdAt = "created_at"
    }
}

struct ICloudSyncInfo: Codable, Hashable {
    let projectId: String
    let projectName: String
    let folderName: String
    let icloudPath: String
    let totalReports: Int
    let reports: [ICloudReport]
    let lastSyncedAt: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case projectName = "project_name"
        case folderName = "folder_name"
        case icloudPath = "icloud_path"
        case totalReports = "total_reports"
        case reports
        case lastSyncedAt = "last_synced_at"
    }
}

