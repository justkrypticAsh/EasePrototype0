// AppEnvironment.swift
import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var isAuthenticated: Bool = true
    @Published var currentUser: User? = User(
        id: "dev-user-001",
        email: "ashish@ease.ai",
        fullName: "Ashish Sharma",
        isActive: true,
        createdAt: nil
    )
    @Published var projects: [Project] = [
        Project(
            id: "ease-core-space",
            name: "EASE Architecture Space",
            description: "In-person discussion capture, speaker separation & cross-discussion memory.",
            domain: "startup",
            languageCode: "auto",
            recordingPolicyText: "Explicit affirmative consent required before recording.",
            role: "owner",
            createdAt: nil
        )
    ]
    @Published var activeProject: Project?
    @Published var errorMessage: String?

    init() {
        if let first = projects.first {
            self.activeProject = first
        }
        // Ensure default token in Keychain for backend API calls
        if KeychainHelper.shared.readString(key: "ease_access_token") == nil {
            KeychainHelper.shared.saveString(key: "ease_access_token", value: "demo-token")
        }
        Task {
            await loadProjects()
        }
    }

    func checkAuthStatus() {
        isAuthenticated = true
    }

    func setSession(tokenResp: TokenResponse) {
        KeychainHelper.shared.saveString(key: "ease_access_token", value: tokenResp.accessToken)
        KeychainHelper.shared.saveString(key: "ease_refresh_token", value: tokenResp.refreshToken)
        KeychainHelper.shared.saveString(key: "ease_user_id", value: tokenResp.userId)

        currentUser = User(
            id: tokenResp.userId,
            email: tokenResp.email,
            fullName: tokenResp.fullName,
            isActive: true,
            createdAt: nil
        )
        isAuthenticated = true

        Task {
            await loadProjects()
        }
    }

    func logout() {
        currentUser = User(
            id: "dev-user-001",
            email: "ashish@ease.ai",
            fullName: "Ashish Sharma",
            isActive: true,
            createdAt: nil
        )
        isAuthenticated = true
    }

    func loadProjects() async {
        do {
            let fetched: [Project] = try await APIClient.shared.request(path: "/projects")
            if !fetched.isEmpty {
                self.projects = fetched
                if activeProject == nil || !fetched.contains(where: { $0.id == activeProject?.id }) {
                    self.activeProject = fetched.first
                }
            }
        } catch {
            print("Backend offline or unreachable, using local prototype space: \(error)")
        }
    }
}
