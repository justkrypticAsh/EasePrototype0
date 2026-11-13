// DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var showCaptureFlow = false
    @State private var showNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectDomain = "consulting"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                // Ambient background lighting
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.easeCyan.opacity(0.12))
                            .frame(width: 280, height: 280)
                            .blur(radius: 80)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.easePurple.opacity(0.1))
                            .frame(width: 250, height: 250)
                            .blur(radius: 70)
                    }
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // User Welcome Header & Quick Capture
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back,")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(env.currentUser?.fullName ?? "Executive")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            // Quick Capture Button with Glass Glow
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showCaptureFlow = true
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.easeRuby)
                                        .frame(width: 8, height: 8)
                                    Text("Capture")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.easeCyan)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                                .shadow(color: Color.easeCyan.opacity(0.4), radius: 10, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal)

                        // iCloud Sync Status Pill
                        HStack {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.easeCyan)
                            Text("iCloud Workspace Connected &bull; Apple ID Sync Active")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Circle()
                                .fill(Color.easeEmerald)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassCard(cornerRadius: 12)
                        .padding(.horizontal)

                        // Projects Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Project Spaces")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Button {
                                    showNewProjectSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("New Space")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.easeCyan)
                                }
                            }
                            .padding(.horizontal)

                            if env.projects.isEmpty {
                                Text("No projects yet. Create your first project space to begin.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(env.projects) { proj in
                                            NavigationLink(destination: ProjectSpaceView(project: proj)) {
                                                projectCard(proj)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // Recent Follow-ups & Cross-Collaborator Blockers
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Collaborator Action Feed")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            VStack(spacing: 10) {
                                // Blocked Task Alert
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.easeAmber.opacity(0.2))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.easeAmber)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Production Database Migration")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Blocked by Priya's action: Security Architecture Review")
                                            .font(.system(size: 11))
                                            .foregroundColor(.easeAmber)
                                    }
                                    Spacer()
                                    GlassStatusPill(title: "Blocked", icon: nil, color: .easeAmber, pulse: true)
                                }
                                .padding(14)
                                .glassCard(cornerRadius: 16, glowColor: .easeAmber, glowRadius: 4)

                                // Completed Prerequisite
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.easeEmerald.opacity(0.2))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.easeEmerald)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Biometric Encryption Vault Implementation")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("AES-256 Fernet voice embedding protection verified")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    GlassStatusPill(title: "Done", icon: nil, color: .easeEmerald)
                                }
                                .padding(14)
                                .glassCard(cornerRadius: 16)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("EASE Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCaptureFlow) {
                CaptureFlowView()
            }
            .sheet(isPresented: $showNewProjectSheet) {
                newProjectSheet
            }
        }
    }

    private func projectCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.domain.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.easeCyan.opacity(0.2))
                    .foregroundColor(.easeCyan)
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 9))
                    Text(project.role?.capitalized ?? "Owner")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.gray)
            }

            Text(project.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(project.description ?? "Active project space with cross-discussion memory.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineLimit(2)

            Spacer()

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10))
                    Text("Enter Space")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.easeCyan)

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.easeCyan)
            }
        }
        .frame(width: 190, height: 155)
        .padding(16)
        .glassCard(cornerRadius: 20, glowColor: .easeCyan, glowRadius: 4, strokeOpacity: 0.3)
    }

    private var newProjectSheet: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROJECT SPACE NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        TextField("e.g. Mobile Core Architecture", text: $newProjectName)
                            .padding()
                            .foregroundColor(.white)
                            .glassCard(cornerRadius: 12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DOMAIN GUIDANCE PRESET (GEMINI FLASH)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        Picker("Preset", selection: $newProjectDomain) {
                            Text("Consulting").tag("consulting")
                            Text("Startup").tag("startup")
                            Text("Construction").tag("construction")
                            Text("Research").tag("research")
                            Text("General").tag("general")
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        createProject()
                    } label: {
                        Text("Create Space & iCloud Folder")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.easeCyan)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                    .disabled(newProjectName.isEmpty)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Project Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewProjectSheet = false }.foregroundColor(.gray)
                }
            }
        }
    }

    private func createProject() {
        Task {
            do {
                let body = try JSONEncoder().encode([
                    "name": newProjectName,
                    "domain": newProjectDomain,
                    "language_code": "auto"
                ])
                let p: Project = try await APIClient.shared.request(path: "/projects", method: "POST", body: body)
                await MainActor.run {
                    env.projects.insert(p, at: 0)
                    showNewProjectSheet = false
                    newProjectName = ""
                }
            } catch {
                print("Failed to create project: \(error)")
            }
        }
    }
}
