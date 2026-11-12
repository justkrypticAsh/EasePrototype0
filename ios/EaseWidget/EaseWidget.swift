// EaseWidget.swift
import WidgetKit
import SwiftUI
import AppIntents

struct PlayBriefIntent: AppIntent {
    static var title: LocalizedStringResource = "Play EASE Brief"
    static var description = IntentDescription("Plays the latest audio brief for your active project.")

    func perform() async throws -> some IntentResult {
        // Trigger audio brief playback
        return .result()
    }
}

struct FollowUpEntry: TimelineEntry {
    let date: Date
    let taskTitle: String
    let projectName: String
    let dueDate: String
    let hasContradiction: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> FollowUpEntry {
        FollowUpEntry(
            date: Date(),
            taskTitle: "Finalize OpenAPI architecture spec",
            projectName: "Project Alpha",
            dueDate: "Friday",
            hasContradiction: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FollowUpEntry) -> ()) {
        let entry = FollowUpEntry(
            date: Date(),
            taskTitle: "Client security review sign-off",
            projectName: "Enterprise Consulting",
            dueDate: "Tomorrow",
            hasContradiction: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FollowUpEntry>) -> ()) {
        let entry = FollowUpEntry(
            date: Date(),
            taskTitle: "Review concrete test reports",
            projectName: "Site Engineering",
            dueDate: "Today @ 4:00 PM",
            hasContradiction: true
        )
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct EaseWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.cyan)
                Text(entry.projectName)
                    .font(.caption2.bold())
                    .foregroundColor(.gray)
                Spacer()
                if entry.hasContradiction {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                }
            }

            Text("Next Follow-up:")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.cyan)

            Text(entry.taskTitle)
                .font(.footnote.bold())
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()

            HStack {
                Text(entry.dueDate)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Button(intent: PlayBriefIntent()) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill").font(.system(size: 8))
                        Text("Brief").font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(4)
                }
            }
        }
        .padding(8)
        .containerBackground(Color(red: 0.08, green: 0.11, blue: 0.18), for: .widget)
    }
}

@main
struct EaseWidget: Widget {
    let kind: String = "EaseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EaseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("EASE Follow-ups")
        .description("Displays upcoming action items and pre-meeting audio briefs.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
