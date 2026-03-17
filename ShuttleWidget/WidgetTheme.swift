import SwiftUI
import AppIntents

struct ColorPalette {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    let highlight: Color /* "Now"/"Moving" */
    let divider: Color
}

enum WidgetTheme: String, AppEnum {
    case system
    case light
    case dark
    case red
    case navy

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Theme"
    static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .system: "System Default",
        .light: "Light",
        .dark: "Dark",
        .red: "Red",
        .navy: "Navy"
    ]

    var palette: ColorPalette {
        switch self {
        case .system, .light, .dark:
            return ColorPalette(
                background: Color(uiColor: .systemBackground),
                primaryText: .primary,
                secondaryText: .secondary,
                highlight: .green,
                divider: Color.primary.opacity(0.2)
            )
        case .red:
            return ColorPalette(
                background: Color(red: 0.75, green: 0.1, blue: 0.15),
                primaryText: .white,
                secondaryText: Color.white.opacity(0.8),
                highlight: Color.yellow,
                divider: Color.white.opacity(0.3)
            )
        case .navy:
            return ColorPalette(
                background: Color(red: 0.05, green: 0.08, blue: 0.15),
                primaryText: Color(white: 0.95),
                secondaryText: Color(red: 0.6, green: 0.7, blue: 0.8),
                highlight: .cyan,
                divider: Color.white.opacity(0.15)
            )
        }
    }
    /* for shadows/default icons, other fixed UI elements */
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark, .red, .navy: return .dark
        case .system: return nil
        }
    }
}
