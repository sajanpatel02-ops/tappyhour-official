import SwiftUI

struct AppTheme {
    let isDark: Bool
    let accent: Color

    var bg: Color { isDark ? Color(hex: "#0b0910") : Color(hex: "#faf7f2") }
    var text: Color { isDark ? Color(hex: "#f5ead6") : Color(hex: "#1a1512") }
    var muted: Color { isDark ? Color(hex: "#f5ead6").opacity(0.55) : Color(hex: "#1a1512").opacity(0.6) }
    var card: Color { isDark ? Color(hex: "#16131c") : .white }
    var cardBorder: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04) }
    var separator: Color { isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }
    var inputBg: Color { isDark ? Color(hex: "#1c1b1f") : .white }
    var sheetBg: Color { bg }

    static let defaultAccent = Color(hex: "#f2a03d")
    static let dark = AppTheme(isDark: true, accent: defaultAccent)
}

enum AccentOption: String, CaseIterable {
    case tungsten = "#f2a03d"
    case ember    = "#ff6b3d"
    case cherry   = "#e8466b"
    case absinthe = "#c9e265"
    case ultra    = "#7d5cff"

    var name: String {
        switch self {
        case .tungsten: "Tungsten"; case .ember: "Ember"; case .cherry: "Cherry"
        case .absinthe: "Absinthe"; case .ultra: "Ultra"
        }
    }
    var color: Color { Color(hex: rawValue) }
}

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
