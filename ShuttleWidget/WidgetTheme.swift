import SwiftUI
import AppIntents

struct ColorPalette {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    let highlight: Color /* "Now"/"Moving" */
    let alert: Color /* "at stop .." */
    let divider: Color
}

enum WidgetTheme: String, AppEnum {
    case system
    case light
    case red
    case navy
    case teal

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Theme"
    static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .system: "System Default",
        .light: "Light",
        .red: "Red",
        .navy: "Navy",
        .teal: "Teal"
    ]

    var palette: ColorPalette {
        switch self {
        case .system, .light:
            return ColorPalette(
                background: Color(uiColor: .systemBackground),
                primaryText: .primary,
                secondaryText: .secondary,
                highlight: .green,
                alert: .red,
                divider: Color.primary.opacity(0.2)
            )
        case .red:
            return ColorPalette(
                background: Color(red: 0.38, green: 0.08, blue: 0.25),
                primaryText: .white,
                secondaryText: Color.white.opacity(0.78),
                highlight: Color(red: 1.0, green: 0.75, blue: 0.9),
                alert: Color(red: 1.0, green: 0.85, blue: 0.9),
                divider: Color.white.opacity(0.22)
            )
        case .navy:
            return ColorPalette(
                background: Color(red: 0.05, green: 0.08, blue: 0.15),
                primaryText: Color(white: 0.95),
                secondaryText: Color(red: 0.6, green: 0.7, blue: 0.8),
                highlight: .cyan,
                alert: .orange,
                divider: Color.white.opacity(0.15)
            )
        case .teal:
            return ColorPalette(
                background: Color(red: 0.06, green: 0.22, blue: 0.24),
                primaryText: Color(white: 0.95),
                secondaryText: Color(red: 0.65, green: 0.82, blue: 0.8),
                highlight: Color(red: 0.4, green: 0.9, blue: 0.75),
                alert: Color(red: 1.0, green: 0.6, blue: 0.5),
                divider: Color.white.opacity(0.18)
            )
        }
    }
    /* for shadows/default icons, other fixed UI elements */
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .red, .navy, .teal: return .dark
        case .system: return .light
        }
    }
}
