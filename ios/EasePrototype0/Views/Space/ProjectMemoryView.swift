// ProjectMemoryView.swift
import SwiftUI

struct ProjectMemoryView: View {
    let projectId: String

    @State private var links: [MemoryLink] = []
    @State private var isLoading = true
    @State private var filterNeedsReview = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 12) {
                // Filter Bar
                HStack {
                    Toggle("Needs Review Only", isOn: $filterNeedsReview)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .tint(.red)
                }
                .padding(.horizontal)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.cyan)
                    Spacer()
                } else if filteredLinks.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No memory connections found")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Cross-meeting links (Confirms, Contradicts, Updates, Resolves) appear as new discussions are processed.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredLinks) { link in
                                memoryLinkCard(link)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .task {
            await loadLinks()
        }
    }

    private var filteredLinks: [MemoryLink] {
        if filterNeedsReview {
            return links.filter { $0.needsReview }
        }
        return links
    }

    private func memoryLinkCard(_ link: MemoryLink) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Relation Badge
                Text(link.relation.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: link.relationColorHex).opacity(0.2))
                    .foregroundColor(Color(hex: link.relationColorHex))
                    .cornerRadius(4)

                if link.needsReview {
                    Text("NEEDS REVIEW")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.3))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }

                Spacer()

                Text("Conf: \(Int(link.judgeConfidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Text(link.shortReason)
                .font(.body)
                .foregroundColor(.white)

            HStack {
                Image(systemName: "link")
                    .font(.caption2)
                    .foregroundColor(.cyan)
                Text("Cross-Meeting Link &bull; Similarity: \(String(format: "%.2f", link.similarity))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.16, blue: 0.24))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(link.needsReview ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func loadLinks() async {
        do {
            let fetched: [MemoryLink] = try await APIClient.shared.request(path: "/projects/\(projectId)/links")
            await MainActor.run {
                links = fetched
                isLoading = false
            }
        } catch {
            print("Failed to load links: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
