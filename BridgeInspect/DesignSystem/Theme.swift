import SwiftUI

/// Shared visual constants.
///
/// The app is used in bridge interiors: low light, gloved hands, a screen that
/// is often dirty or wet. Colour reinforces status but never carries it alone —
/// every state is distinguishable by shape with the colour removed.
enum Theme {

    // MARK: Metrics

    enum Metrics {
        /// Comfortably above the 44pt minimum, since taps are made with gloves.
        static let rowHeight: CGFloat = 60
        static let headerHeight: CGFloat = 34
        static let wallColumnWidth: CGFloat = 44
        static let noteColumnWidth: CGFloat = 42
        /// Sized so all inspection columns fit a 393pt iPhone without scrolling.
        static let cellWidth: CGFloat = 45
        static let corner: CGFloat = 10
        static let cardCorner: CGFloat = 14
    }

    // MARK: Colours

    /// Deep slate rather than pure black, and desaturated status hues chosen to
    /// stay distinguishable under a headlamp and through a scratched screen
    /// protector. All defined for both light and dark appearance.
    enum Palette {

        // Status
        static let done = Color(
            light: Color(red: 0.13, green: 0.47, blue: 0.31),
            dark:  Color(red: 0.35, green: 0.78, blue: 0.55)
        )
        static let todo = Color(
            light: Color(red: 0.42, green: 0.45, blue: 0.50),
            dark:  Color(red: 0.62, green: 0.66, blue: 0.72)
        )
        static let notApplicable = Color(
            light: Color(red: 0.66, green: 0.69, blue: 0.73),
            dark:  Color(red: 0.42, green: 0.46, blue: 0.52)
        )
        /// Reserved for genuine attention states, not ordinary "not started".
        static let attention = Color(
            light: Color(red: 0.72, green: 0.47, blue: 0.09),
            dark:  Color(red: 0.95, green: 0.71, blue: 0.29)
        )

        // Surfaces
        static let accent = Color(
            light: Color(red: 0.13, green: 0.36, blue: 0.62),
            dark:  Color(red: 0.42, green: 0.66, blue: 0.95)
        )
        static let headerFill = Color(
            light: Color(red: 0.95, green: 0.96, blue: 0.97),
            dark:  Color(red: 0.13, green: 0.14, blue: 0.16)
        )
        static let rowStripe = Color(
            light: Color(red: 0.97, green: 0.975, blue: 0.98),
            dark:  Color(red: 0.11, green: 0.12, blue: 0.14)
        )
        static let card = Color(
            light: .white,
            dark:  Color(red: 0.10, green: 0.11, blue: 0.13)
        )
        static let hairline = Color(
            light: Color(red: 0.88, green: 0.89, blue: 0.91),
            dark:  Color(red: 0.22, green: 0.24, blue: 0.27)
        )
        static let pressed = Color.primary.opacity(0.10)
        static let track = Color(
            light: Color(red: 0.90, green: 0.91, blue: 0.93),
            dark:  Color(red: 0.20, green: 0.22, blue: 0.25)
        )
    }

    // MARK: Type

    enum Fonts {
        /// Monospaced so wall labels and counts stay column-aligned.
        static let wallLabel = Font.system(.body, design: .monospaced).weight(.semibold)
        static let columnHeader = Font.system(.caption2, design: .default).weight(.semibold)
        static let metric = Font.system(.caption, design: .monospaced).weight(.medium)
    }
}

/// Resolves a different colour per appearance without an asset catalog.
extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

extension InspectionStatus {
    var tint: Color {
        switch self {
        case .completed: Theme.Palette.done
        case .notStarted: Theme.Palette.todo
        case .notApplicable: Theme.Palette.notApplicable
        }
    }
}

/// A single inspection status rendered as a shape first, colour second.
///
/// Filled / hollow / bar reads correctly with the colour stripped out, which
/// matters for colour-blind users and for a screen viewed at a bad angle.
struct StatusGlyph: View {
    let status: InspectionStatus
    var size: CGFloat = 15

    var body: some View {
        switch status {
        case .completed:
            Circle()
                .fill(status.tint)
                .frame(width: size, height: size)
        case .notStarted:
            Circle()
                .strokeBorder(status.tint.opacity(0.75), lineWidth: 1.7)
                .frame(width: size, height: size)
        case .notApplicable:
            Capsule()
                .fill(status.tint)
                .frame(width: size * 0.72, height: 2.5)
        }
    }
}

/// Thin bar showing how much of a space is documented.
struct CompletionBar: View {
    let fraction: Double
    var height: CGFloat = 5

    private var tint: Color {
        fraction >= 1 ? Theme.Palette.done : Theme.Palette.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.25), value: fraction)
    }
}
