// AppleEcosystemView.swift
import SwiftUI

struct AppleEcosystemView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var autoSyncICloud: Bool = true
    @State private var isSyncing: Bool = false
    @State private var syncStatusMessage: String? = "All project reports synced with iCloud Drive"
    @State private var activeShareReport: ICloudReport?
    @State private var showShareSheet: Bool = false
    @State private var sampleReports: [ICloudReport] = [
        ICloudReport(
            filename: "Launch_Kickoff_Architecture_Report.md",
            meetingId: "meeting-launch-001",
            title: "Product Launch Architecture & Scope Kickoff",
            contentMarkdown: """
            # EASE Executive Discussion Report
            **Project**: Product Launch
            **Date**: November 13, 2026
            **Participants**: Aarav Mehta (Owner), Riya Sharma (Editor), Kabir Singh (Contributor)

            ## Strategic Decisions
            1. **Adopt Gemini Flash 1.5** for low-latency analysis (<1.2s round-trip).
            2. **Enforce AES-256 local biometric voice vault** on iOS devices.

            ## Key Claims
            - Gemini Flash meets 1.2s round-trip SLA (Riya Sharma, 0.98 confidence).
            - Production PostgreSQL migration requires 48h maintenance window (Kabir Singh).

            ## Blocker Dependencies
            - **Blocked**: Kabir Singh cannot start PostgreSQL migration until Riya Sharma signs off on Client Security Architecture.
            """,
            summary: "Approved Gemini Flash 1.5 and AES-256 biometric encryption on iOS; mapped PostgreSQL blocker dependency.",
            decisionsCount: 2,
            claimsCount: 2,
            prerequisitesCount: 4,
            createdAt: "2026-11-13"
        ),
        ICloudReport(
            filename: "Security_Audit_Readiness_Report.md",
            meetingId: "meeting-launch-002",
            title: "Security Audit & Launch Readiness Sync",
            contentMarkdown: """
            # EASE Executive Discussion Report
            **Project**: Product Launch
            **Date**: November 13, 2026
            **Participants**: Aarav Mehta (Owner), Neha Kapoor (Viewer)

            ## Privacy & Compliance Verification
            - Verified zero unconsented audio transmission policy.
            - Confirmed instant local purge capability for voice enrollment data.
            """,
            summary: "Verified zero unconsented audio transmission policy and instant local purge capability.",
            decisionsCount: 1,
            claimsCount: 0,
            prerequisitesCount: 0,
            createdAt: "2026-11-13"
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                // Ambient background glows
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.easeCyan.opacity(0.12))
                            .frame(width: 270, height: 270)
                            .blur(radius: 80)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.easeEmerald.opacity(0.09))
                            .frame(width: 250, height: 250)
                            .blur(radius: 70)
                    }
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Ecosystem Hub")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Deep integration with iCloud, Apple Watch, and iOS Widgets")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        // 1. iCloud Shared Storage Section
                        iCloudStorageSection
                            .padding(.horizontal)

                        // 2. Apple Watch Remote Section
                        appleWatchSection
                            .padding(.horizontal)

                        // 3. Home Screen & Lock Screen Widgets Section
                        widgetsSection
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Apple Ecosystem")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                if let rep = activeShareReport {
                    ShareSheetView(activityItems: [
                        rep.contentMarkdown,
                        "EASE Discussion Report: \(rep.title)"
                    ])
                }
            }
        }
    }

    // MARK: - iCloud Section
    private var iCloudStorageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.easeCyan)
                    Text("iCloud Shared Drive")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                GlassStatusPill(title: "Active", icon: "checkmark.circle.fill", color: .easeEmerald)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Storage Path:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    Text("iCloud Drive ❯ EASE ❯ Reports")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.easeCyan)
                }

                Toggle(isOn: $autoSyncICloud) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Sync Discussion Reports")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Automatically writes markdown reports to shared iCloud folder")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.easeCyan)
            }
            .padding(12)
            .glassCard(cornerRadius: 12)

            // Reports List
            VStack(alignment: .leading, spacing: 10) {
                Text("Discussion Reports Ready for Sharing")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                ForEach(sampleReports) { report in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.easeCyan.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.easeCyan)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("\(report.filename) • \(report.decisionsCount) decisions • \(report.prerequisitesCount) tasks")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            activeShareReport = report
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.easeCyan)
                                .padding(8)
                                .background(Color.easeCyan.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(10)
                    .glassCard(cornerRadius: 12)
                }
            }

            // Sync Button
            Button {
                triggerSync()
            } label: {
                HStack {
                    if isSyncing {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Force Sync iCloud Workspace")
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.easeCyan)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSyncing)

            if let msg = syncStatusMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.easeEmerald)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18, glowColor: .easeCyan, glowRadius: 4)
    }

    // MARK: - Apple Watch Section
    private var appleWatchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .foregroundColor(.easePurple)
                    Text("Apple Watch Remote")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                GlassStatusPill(title: "Paired", icon: "antenna.radiowaves.left.and.right", color: .easeEmerald)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.easeAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Consent Synchronization")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Watch controls are locked until phone confirms participant consent")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                HStack(spacing: 12) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.easeCyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Recording Remote")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Start, pause, and mark key decisions directly from watch face")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 12)
        }
        .padding(16)
        .glassCard(cornerRadius: 18, glowColor: .easePurple, glowRadius: 4)
    }

    // MARK: - Widgets Section
    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundColor(.easeAmber)
                    Text("iOS Widgets & App Intents")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                GlassStatusPill(title: "Configured", icon: "widget.small", color: .easeCyan)
            }

            VStack(spacing: 10) {
                widgetPreviewRow(
                    name: "Quick Capture Widget",
                    type: "Home Screen (Small / Medium)",
                    desc: "1-tap discussion capture with pre-selected active project space"
                )

                widgetPreviewRow(
                    name: "Blocker & Task Radar",
                    type: "Home Screen & Lock Screen",
                    desc: "Live glance at blocked prerequisites and awaiting collaborator actions"
                )

                widgetPreviewRow(
                    name: "Pre-Meeting Audio Briefing",
                    type: "Interactive Widget",
                    desc: "Play 60-second spoken briefing before entering project discussions"
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18, glowColor: .easeAmber, glowRadius: 4)
    }

    private func widgetPreviewRow(name: String, type: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: "widget.small")
                    .font(.system(size: 13))
                    .foregroundColor(.easeCyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(type)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.easeCyan)
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(10)
        .glassCard(cornerRadius: 12)
    }

    private func triggerSync() {
        isSyncing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            // Simulate iCloud workspace file sync
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                isSyncing = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                syncStatusMessage = "✓ Synced with iCloud Drive at \(Date().formatted(date: .omitted, time: .standard))"
            }
        }
    }
}
