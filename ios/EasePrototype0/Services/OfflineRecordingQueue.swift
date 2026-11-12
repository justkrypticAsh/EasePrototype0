// OfflineRecordingQueue.swift
import Foundation

struct PendingRecording: Codable, Identifiable {
    let id: String
    let projectId: String
    let title: String
    let localFilePath: String
    let participants: [String]
    let recordedAt: Date
    var retryCount: Int
}

final class OfflineRecordingQueue: ObservableObject {
    static let shared = OfflineRecordingQueue()

    @Published var pendingRecordings: [PendingRecording] = []

    private let storageKey = "ease_pending_recordings_queue"

    private init() {
        loadQueue()
    }

    func enqueue(projectId: String, title: String, fileURL: URL, participants: [String]) {
        let item = PendingRecording(
            id: UUID().uuidString,
            projectId: projectId,
            title: title,
            localFilePath: fileURL.path,
            participants: participants,
            recordedAt: Date(),
            retryCount: 0
        )
        pendingRecordings.append(item)
        saveQueue()
    }

    func dequeue(id: String) {
        pendingRecordings.removeAll { $0.id == id }
        saveQueue()
    }

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(pendingRecordings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([PendingRecording].self, from: data) {
            pendingRecordings = items
        }
    }

    func flushQueue() async {
        for item in pendingRecordings {
            let fileURL = URL(fileURLWithPath: item.localFilePath)
            guard FileManager.default.fileExists(atPath: item.localFilePath) else {
                dequeue(id: item.id)
                continue
            }

            do {
                _ = try await APIClient.shared.uploadMeeting(
                    projectId: item.projectId,
                    audioFileURL: fileURL,
                    title: item.title,
                    participants: item.participants,
                    spokenAnnouncementPlayed: true
                )
                dequeue(id: item.id)
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Retry upload failed for \(item.title): \(error)")
            }
        }
    }
}
