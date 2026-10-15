import SwiftUI
import WidgetKit

@main
struct StreakPalsWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakHabitWidget()
        TodayBoardWidget()
    }
}

struct StreakHabitWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StreakHabit", intent: SelectHabitIntent.self, provider: HabitTimeline()) { entry in
            HabitWidgetView(entry: entry)
                .containerBackground(WidgetTheme.background, for: .widget)
        }
        .configurationDisplayName("One habit")
        .description("See a streak and check in without opening the app.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodayBoardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayBoard", provider: BoardTimeline()) { entry in
            BoardWidgetView(entry: entry)
                .containerBackground(WidgetTheme.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("The habits you're keeping with your pals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
