import SwiftUI
import UIKit

enum Theme {
    static let background = dynamic(light: rgb(1.00, 0.965, 0.945), dark: rgb(0.07, 0.055, 0.05))
    static let card = dynamic(light: rgb(1, 1, 1), dark: rgb(0.16, 0.11, 0.09))
    static let ink = dynamic(light: rgb(0.17, 0.09, 0.06), dark: rgb(1.00, 0.965, 0.94))
    static let muted = dynamic(light: rgb(0.55, 0.42, 0.37), dark: rgb(0.79, 0.66, 0.60))
    static let line = dynamic(light: rgb(0.94, 0.88, 0.84), dark: rgb(0.24, 0.17, 0.14))
    static let ember = dynamic(light: rgb(0.886, 0.239, 0.071), dark: rgb(1.00, 0.42, 0.24))
    static let gold = dynamic(light: rgb(0.94, 0.64, 0.01), dark: rgb(1.00, 0.76, 0.30))
    static let good = dynamic(light: rgb(0.12, 0.54, 0.30), dark: rgb(0.45, 0.82, 0.55))
    static let widgetBackground = dynamic(light: rgb(1.00, 0.95, 0.92), dark: rgb(0.12, 0.08, 0.07))

    static func color(_ hex: String) -> Color {
        var rgb: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: cleaned).scanHexInt64(&rgb)
        guard cleaned.count == 6 else { return ember }
        let red = Double((rgb & 0xFF0000) >> 16) / 255
        let green = Double((rgb & 0x00FF00) >> 8) / 255
        let blue = Double(rgb & 0x0000FF) / 255
        return Color(red: red, green: green, blue: blue)
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
