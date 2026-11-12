// AppEnvironment.swift
import Foundation
import Combine

final class AppEnvironment: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var projects: [Project] = []
    @Published var activeProject: Project?
    @Published var errorMessage: String?

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if let token = KeychainHelper.shared.readString(key: "ease_access_token") {
            isAuthenticated = !token.isEmpty
            if isAuthenticated {
                Task {
                    await loadProjects()
                }
            }
        }
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
        KeychainHelper.shared.delete(key: "ease_access_token")
        KeychainHelper.shared.delete(key: "ease_refresh_token")
        KeychainHelper.shared.delete(key: "ease_user_id")
        isAuthenticated = false
        currentUser = nil
        projects = []
        activeProject = nil
    }

    @MainActor
    func loadProjects() async {
        do {
            let fetched: [Project] = try await APIClient.shared.request(path: "/projects")
            self.projects = fetched
            if activeProject == nil, let first = fetched.first {
                self.activeProject = first
            }
        } catch {
            print("Failed to load projects: \(error)")
        }
    }
}
