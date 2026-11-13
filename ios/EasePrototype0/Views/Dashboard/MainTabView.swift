// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCapture = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Home / Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                }
                .tag(0)

            // 2. Project Space
            ProjectSpaceContainerView()
                .tabItem {
                    Label("Project Space", systemImage: "brain.head.profile")
                }
                .tag(1)

            // 3. Quick Capture Discussion
            Color.clear
                .tabItem {
                    Label("Capture", systemImage: "record.circle.fill")
                }
                .tag(2)

            // 4. Planning & Scheduling
            PlanningView()
                .tabItem {
                    Label("Planning", systemImage: "calendar.badge.clock")
                }
                .tag(3)

            // 5. Apple Ecosystem (iCloud, Watch, Widgets)
            AppleEcosystemView()
                .tabItem {
                    Label("Ecosystem", systemImage: "applelogo")
                }
                .tag(4)

            // 6. Settings & Data Privacy
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .tint(.easeCyan)
        .onChange(of: selectedTab) { oldVal, newVal in
            if newVal == 2 {
                selectedTab = oldVal
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showCapture = true
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureFlowView()
        }
    }
}
