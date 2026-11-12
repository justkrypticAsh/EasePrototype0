// MembersView.swift
import SwiftUI

struct MembersView: View {
    let projectId: String
    @State private var members: [ProjectMember] = []
    @State private var isLoading = true
    @State private var inviteCode: String?
    @State private var isCreatingInvite = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 16) {
                // Invite section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Invite Collaborator")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let code = inviteCode {
                        HStack {
                            Text("Code: \(code)")
                                .font(.body.monospaced())
                                .foregroundColor(.cyan)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = code
                            }
                            .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                        .cornerRadius(8)
                    }

                    Button {
                        createInvite()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Generate Project Invite Link")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .disabled(isCreatingInvite)
                }
                .padding()
                .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                .cornerRadius(12)
                .padding(.horizontal)

                // Member list
                List(members) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.fullName)
                                .font(.body.bold())
                                .foregroundColor(.white)
                            Text(m.email)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(m.role.capitalized)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(m.role == "owner" ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundColor(m.role == "owner" ? .purple : .blue)
                            .cornerRadius(4)
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.16, blue: 0.24))
                }
                .listStyle(.plain)
            }
        }
        .task {
            await loadMembers()
        }
    }

    private func loadMembers() async {
        do {
            let fetched: [ProjectMember] = try await APIClient.shared.request(path: "/projects/\(projectId)/members")
            await MainActor.run {
                members = fetched
                isLoading = false
            }
        } catch {
            print("Failed to load members: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func createInvite() {
        isCreatingInvite = true
        Task {
            do {
                let body = try JSONEncoder().encode(["max_uses": 5, "expires_in_days": 7])
                let res: [String: AnyCodable] = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/invites",
                    method: "POST",
                    body: body
                )
                await MainActor.run {
                    inviteCode = res["code"]?.stringValue
                    isCreatingInvite = false
                }
            } catch {
                print("Failed to create invite: \(error)")
                await MainActor.run { isCreatingInvite = false }
            }
        }
    }
}

// Simple AnyCodable helper
struct AnyCodable: Codable {
    let stringValue: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            stringValue = s
        } else if let i = try? container.decode(Int.self) {
            stringValue = String(i)
        } else {
            stringValue = nil
        }
    }
    func encode(to encoder: Encoder) throws {}
}
