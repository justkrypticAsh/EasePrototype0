// BriefingView.swift
import SwiftUI

struct BriefingView: View {
    let projectId: String
    @StateObject private var speechSynth = SpeechSynthesizerService.shared

    @State private var brief: BriefResponse?
    @State private var isLoadingBrief = true
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchAnswer: SearchAnswerResponse?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.12).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Audio Brief Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "headphones")
                                .foregroundColor(.cyan)
                            Text("Pre-Meeting Audio Brief")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("60-90s")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.2))
                                .foregroundColor(.cyan)
                                .cornerRadius(4)
                        }

                        if isLoadingBrief {
                            HStack {
                                ProgressView().tint(.cyan)
                                Text("Generating executive brief...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        } else if let b = brief {
                            Text(b.spokenScript)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(speechSynth.isSpeaking ? nil : 4)

                            HStack(spacing: 12) {
                                Button {
                                    if speechSynth.isSpeaking {
                                        speechSynth.stop()
                                    } else {
                                        speechSynth.speak(text: b.spokenScript)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: speechSynth.isSpeaking ? "stop.fill" : "play.fill")
                                        Text(speechSynth.isSpeaking ? "Stop Brief" : "Play Brief (AirPods / Audio)")
                                    }
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(speechSynth.isSpeaking ? Color.red : Color.cyan)
                                    .foregroundColor(.black)
                                    .cornerRadius(8)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(b.latestDecisionsCount) Decisions")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("\(b.pendingPrerequisitesCount) Pending")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(12)

                    // "Ask this project" Natural Language Search
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.cyan)
                            Text("Ask This Project")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        HStack {
                            TextField("e.g. What did we decide about the database?", text: $searchQuery)
                                .padding()
                                .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                                .cornerRadius(8)
                                .foregroundColor(.white)

                            Button {
                                executeSearch()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(searchQuery.isEmpty ? .gray : .cyan)
                            }
                            .disabled(searchQuery.isEmpty || isSearching)
                        }

                        if isSearching {
                            HStack {
                                ProgressView().tint(.cyan)
                                Text("Searching verified project discussions...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else if let answer = searchAnswer {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(answer.answer)
                                    .font(.body)
                                    .foregroundColor(.white)

                                if !answer.citations.isEmpty {
                                    Text("Source Citations:")
                                        .font(.caption.bold())
                                        .foregroundColor(.cyan)
                                        .padding(.top, 4)

                                    ForEach(answer.citations) { cite in
                                        HStack(alignment: .top) {
                                            Image(systemName: "quote.bubble.fill")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\"\(cite.quote)\"")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.85))
                                                Text("\(cite.meetingTitle) &bull; [\(cite.timestampStartMs/1000)s - \(cite.timestampEndMs/1000)s]")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(8)
                                        .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(red: 0.10, green: 0.14, blue: 0.22))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .task {
            await loadBrief()
        }
    }

    private func loadBrief() async {
        do {
            let res: BriefResponse = try await APIClient.shared.request(path: "/projects/\(projectId)/brief")
            await MainActor.run {
                brief = res
                isLoadingBrief = false
            }
        } catch {
            print("Failed to load brief: \(error)")
            await MainActor.run { isLoadingBrief = false }
        }
    }

    private func executeSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        searchAnswer = nil

        Task {
            do {
                let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let res: SearchAnswerResponse = try await APIClient.shared.request(
                    path: "/projects/\(projectId)/search?q=\(encodedQuery)"
                )
                await MainActor.run {
                    searchAnswer = res
                    isSearching = false
                }
            } catch {
                print("Search failed: \(error)")
                await MainActor.run { isSearching = false }
            }
        }
    }
}
