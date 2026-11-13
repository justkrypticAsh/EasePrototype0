// ICloudWorkspaceService.swift
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ICloudWorkspaceService: ObservableObject {
    static let shared = ICloudWorkspaceService()

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var syncedReportsCount: Int = 0
    @Published var sharedFolderURL: URL? = nil
    @Published var errorMessage: String? = nil

    private init() {
        setupLocalProjectFolder()
    }

    /// Root directory for iCloud / Local Documents
    var baseStorageDirectory: URL {
        // Try iCloud Drive container first, fallback to App Documents
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let easeFolder = containerURL.appendingPathComponent("Documents").appendingPathComponent("EASE")
            try? FileManager.default.createDirectory(at: easeFolder, withIntermediateDirectories: true)
            return easeFolder
        } else {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let easeFolder = docDir.appendingPathComponent("EASE")
            try? FileManager.default.createDirectory(at: easeFolder, withIntermediateDirectories: true)
            return easeFolder
        }
    }

    private func setupLocalProjectFolder() {
        let base = baseStorageDirectory
        sharedFolderURL = base
    }

    /// Prepares local/iCloud project directory: EASE / Projects / [Project Name] / Reports
    func getProjectReportsDirectory(projectName: String) -> URL {
        let safeName = projectName.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_")).inverted).joined()
        let projectFolder = baseStorageDirectory.appendingPathComponent(safeName.isEmpty ? "Project" : safeName)
        let reportsFolder = projectFolder.appendingPathComponent("Reports")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        return reportsFolder
    }

    /// Syncs and saves discussion markdown reports into iCloud / Files folder
    func syncReportsToICloud(projectName: String, reports: [ICloudReport]) async -> [URL] {
        isSyncing = true
        var savedURLs: [URL] = []
        let reportsFolder = getProjectReportsDirectory(projectName: projectName)

        for report in reports {
            let fileURL = reportsFolder.appendingPathComponent(report.filename)
            do {
                try report.contentMarkdown.write(to: fileURL, atomically: true, encoding: .utf8)
                savedURLs.append(fileURL)
            } catch {
                print("Failed to write report \(report.filename): \(error)")
            }
        }

        self.syncedReportsCount = savedURLs.count
        self.lastSyncDate = Date()
        self.sharedFolderURL = reportsFolder
        self.isSyncing = false
        return savedURLs
    }
}

/// Native SwiftUI Share Sheet Wrapper for iOS
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
