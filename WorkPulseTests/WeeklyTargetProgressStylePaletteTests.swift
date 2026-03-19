import AppKit
import Testing
@testable import WorkPulse

struct WeeklyTargetProgressStylePaletteTests {
    private let palette = WeeklyTargetProgressStylePalette()

    @Test("palette maps caution style to system orange")
    func paletteMapsCautionStyleToSystemOrange() {
        #expect(palette.textColor(for: .caution).isEqual(NSColor.systemOrange))
    }

    @Test("palette maps success style to system green")
    func paletteMapsSuccessStyleToSystemGreen() {
        #expect(palette.textColor(for: .success).isEqual(NSColor.systemGreen))
    }

    @Test("palette maps danger style to system red")
    func paletteMapsDangerStyleToSystemRed() {
        #expect(palette.textColor(for: .danger).isEqual(NSColor.systemRed))
    }
}
