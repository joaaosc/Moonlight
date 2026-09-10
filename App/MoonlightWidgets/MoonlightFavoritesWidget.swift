import AppIntents
import MoonlightDomain
import MoonlightIntents
import SwiftUI
import WidgetKit

/// Chooses which commands a widget instance shows.
///
/// Configuration is per instance, so two widgets on the same desktop keep
/// their own selection.
struct SelectCommandsIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Commands"
    static let description = IntentDescription(
        "Pick the Moonlight commands this widget shows."
    )

    @Parameter(title: "Commands")
    var commands: [MoonlightToolEntity]?

    init() {}

    init(commands: [MoonlightToolEntity]) {
        self.commands = commands
    }
}

struct MoonlightCommandsEntry: TimelineEntry {
    let date: Date
    let commands: [MoonlightToolEntity]
}

struct MoonlightCommandsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MoonlightCommandsEntry {
        MoonlightCommandsEntry(date: .distantPast, commands: Self.fallbackCommands)
    }

    /// Reading the catalog is the only work here. A refresh must never run a
    /// command: the widget shows what exists, it does not act.
    func snapshot(
        for configuration: SelectCommandsIntent,
        in context: Context
    ) async -> MoonlightCommandsEntry {
        MoonlightCommandsEntry(
            date: .distantPast,
            commands: Self.commands(for: configuration)
        )
    }

    func timeline(
        for configuration: SelectCommandsIntent,
        in context: Context
    ) async -> Timeline<MoonlightCommandsEntry> {
        let entry = MoonlightCommandsEntry(
            date: .distantPast,
            commands: Self.commands(for: configuration)
        )
        // The catalog changes only when the user edits it, and editing already
        // reloads the timelines. Polling would add cost with nothing to gain.
        return Timeline(entries: [entry], policy: .never)
    }

    private static func commands(for configuration: SelectCommandsIntent) -> [MoonlightToolEntity] {
        let selected = configuration.commands ?? []
        return selected.isEmpty ? fallbackCommands : selected
    }

    private static var fallbackCommands: [MoonlightToolEntity] {
        Array(MoonlightToolEntityQuery.allEntities.prefix(4))
    }
}

struct MoonlightFavoritesWidget: Widget {
    static let kind = "MoonlightFavorites"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectCommandsIntent.self,
            provider: MoonlightCommandsProvider()
        ) { entry in
            MoonlightFavoritesView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Moonlight Commands")
        .description("Run your Moonlight commands from the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MoonlightFavoritesView: View {
    let entry: MoonlightCommandsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.commands.prefix(4)) { command in
                // The button runs the intent in the app process, which is the
                // only place that can reach Apple Events for personal commands.
                Button(intent: RunUserShortcutIntent(command: command)) {
                    Label(command.name, systemImage: command.symbolName)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if entry.commands.isEmpty {
                Text("No commands available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
