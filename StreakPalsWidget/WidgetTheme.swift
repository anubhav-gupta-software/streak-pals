import SwiftUI
import UIKit
import WidgetKit

enum WidgetTheme {
    static let ink = dynamic(light: rgb(0.17, 0.09, 0.06), dark: rgb(1.00, 0.965, 0.94))
    static let muted = dynamic(light: rgb(0.45, 0.32, 0.27), dark: rgb(0.79, 0.66, 0.60))
    static let ember = dynamic(light: rgb(0.886, 0.239, 0.071), dark: rgb(1.00, 0.42, 0.24))
    static let background = dynamic(light: rgb(1.00, 0.965, 0.945), dark: rgb(0.12, 0.08, 0.07))

    static func color(_ hex: String) -> Color {
        var rgb: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: cleaned).scanHexInt64(&rgb)
        guard cleaned.count == 6 else { return ember }
        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct HabitEntry: TimelineEntry {
    var date: Date
    var habit: WidgetHabit?
    var palName: String
    var usesAppGroup: Bool
    var hasPayload: Bool
}

struct BoardEntry: TimelineEntry {
    var date: Date
    var habits: [WidgetHabit]
    var palName: String
    var usesAppGroup: Bool
    var hasPayload: Bool
}
