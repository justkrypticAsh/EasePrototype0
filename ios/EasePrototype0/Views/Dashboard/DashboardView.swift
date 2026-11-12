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
                Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // User Welcome Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back,")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text(env.currentUser?.fullName ?? "Executive")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            // Quick Capture Button
                            Button {
                                showCaptureFlow = true
                            } label: {
                                HStack {
                                    Image(systemName: "record.circle")
                                    Text("Capture")
                                }
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.cyan)
                                .foregroundColor(.black)
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal)

                        // Projects Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("My Projects")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Button("+ New Project") {
                                    showNewProjectSheet = true
                                }
                                .font(.footnote.bold())
                                .foregroundColor(.cyan)
                            }
                            .padding(.horizontal)

                            if env.projects.isEmpty {
                                Text("No projects yet. Create your first project space to begin.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
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

                        // Recent Activity & Pending Tasks
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Follow-ups")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            VStack(spacing: 8) {
                                HStack {
                                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                                    Text("Finalize OpenAPI specification")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("By Friday")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                                .cornerRadius(8)

                                HStack {
                                    Circle().fill(Color.green).frame(width: 8, height: 8)
                                    Text("Client Security Review Sign-off")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Confirmed")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(project.domain.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(4)
                Spacer()
                Text(project.role?.capitalized ?? "Member")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Text(project.name)
                .font(.body.bold())
                .foregroundColor(.white)
                .lineLimit(1)

            Text(project.description ?? "Active project space")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(2)

            Spacer()

            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.gray)
                Text("Open Space")
                    .font(.caption2.bold())
                    .foregroundColor(.cyan)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .frame(width: 170, height: 140)
        .padding()
        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
        .cornerRadius(12)
    }

    private var newProjectSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField("Project Name", text: $newProjectName)
                        .padding()
                        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .cornerRadius(8)
                        .foregroundColor(.white)

                    Picker("Domain Guidance Preset", selection: $newProjectDomain) {
                        Text("Consulting").tag("consulting")
                        Text("Startup").tag("startup")
                        Text("Construction").tag("construction")
                        Text("Research").tag("research")
                        Text("General").tag("general")
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                    Button("Create Space") {
                        createProject()
                    }
                    .disabled(newProjectName.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(8)

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
