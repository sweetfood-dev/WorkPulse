import AppKit

struct WeeklyTargetProgressStylePalette {
    func textColor(for style: WeeklyTargetProgressSemanticStyle) -> NSColor {
        switch style {
        case .caution:
            return .systemOrange
        case .success:
            return .systemGreen
        case .danger:
            return .systemRed
        }
    }
}
