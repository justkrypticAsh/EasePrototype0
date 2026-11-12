// EaseApp.swift
import SwiftUI

@main
struct EaseApp: App {
    @StateObject private var env = AppEnvironment()
    @StateObject private var watchManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(env)
                .preferredColorScheme(.dark)
        }
    }
}
