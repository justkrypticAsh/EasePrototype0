// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCapture = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                }
                .tag(0)

            Color.clear
                .tabItem {
                    Label("Capture", systemImage: "record.circle.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.cyan)
        .onChange(of: selectedTab) { oldVal, newVal in
            if newVal == 1 {
                selectedTab = oldVal
                showCapture = true
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureFlowView()
        }
    }
}
