// ProjectSpaceContainerView.swift
import SwiftUI

struct ProjectSpaceContainerView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var showCreateProjectSheet: Bool = false
    @State private var newProjectName: String = ""
    @State private var newProjectDomain: String = "startup"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                if let current = env.activeProject ?? env.projects.first {
                    VStack(spacing: 0) {
                        // Project Switcher Bar
                        HStack {
                            Menu {
                                ForEach(env.projects) { p in
                                    Button {
                                        env.activeProject = p
                                    } label: {
                                        HStack {
                                            Text(p.name)
                                            if p.id == current.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }

                                Divider()

                                Button {
                                    showCreateProjectSheet = true
                                } label: {
                                    Label("Create New Project Space", systemImage: "plus")
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(current.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.easeCyan)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }

                            Spacer()

                            GlassStatusPill(
                                title: current.role?.capitalized ?? "Owner",
                                icon: "icloud.fill",
                                color: .easeCyan
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        // Child ProjectSpaceView with all 6 sub-sections
                        ProjectSpaceView(project: current)
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.easeCyan)
                        Text("No Project Spaces Found")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Create your first project space to start capturing discussions and building project memory.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            showCreateProjectSheet = true
                        } label: {
                            Text("Create Project Space")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.easeCyan)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreateProjectSheet) {
                createProjectSheet
            }
        }
    }

    private var createProjectSheet: some View {
        NavigationStack {
            ZStack {
                Color.easeBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROJECT SPACE NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        TextField("e.g. Mobile Architecture Space", text: $newProjectName)
                            .padding()
                            .foregroundColor(.white)
                            .glassCard(cornerRadius: 12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DOMAIN GUIDANCE PRESET (GEMINI FLASH)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.easeCyan)

                        Picker("Preset", selection: $newProjectDomain) {
                            Text("Startup").tag("startup")
                            Text("Consulting").tag("consulting")
                            Text("Construction").tag("construction")
                            Text("Research").tag("research")
                            Text("General").tag("general")
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        createProject()
                    } label: {
                        Text("Create Space & iCloud Drive Folder")
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
                    Button("Cancel") { showCreateProjectSheet = false }.foregroundColor(.gray)
                }
            }
        }
    }

    private func createProject() {
        let p = Project(
            id: UUID().uuidString,
            name: newProjectName,
            description: "Active project space with cross-discussion memory.",
            domain: newProjectDomain,
            languageCode: "auto",
            recordingPolicyText: "Explicit affirmative consent required before recording.",
            role: "owner",
            createdAt: nil
        )
        env.projects.insert(p, at: 0)
        env.activeProject = p
        showCreateProjectSheet = false
        newProjectName = ""
    }
}

