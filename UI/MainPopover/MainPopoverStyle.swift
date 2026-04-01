import AppKit

enum MainPopoverStyle {
    enum Tokens {
        enum Brand {
            static var accentStart: NSColor { .systemBlue }
            static var accentEnd: NSColor {
                NSColor(calibratedRed: 0.00, green: 0.42, blue: 0.95, alpha: 1)
            }
        }

        enum Effects {
            static var cardShadow: NSColor { .black.withAlphaComponent(0.16) }
        }
    }

    enum Metrics {
        static let popoverSize = NSSize(width: 392, height: 488)
        static let contentSpacing: CGFloat = 0
        static let dividerHeight: CGFloat = 1
        static let progressBarHeight: CGFloat = 10
        static let valuePillWidth: CGFloat = 110
        static let valuePillHeight: CGFloat = 50
        static let currentSessionTitleKern: CGFloat = 1.4

        static let headerInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        static let currentSessionInsets = NSEdgeInsets(top: 26, left: 26, bottom: 26, right: 26)
        static let summaryInsets = NSEdgeInsets(top: 16, left: 20, bottom: 18, right: 20)
        static let todayTimesInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        static let headerSpacing: CGFloat = 10
        static let currentSessionSpacing: CGFloat = 16
        static let todayTimesSpacing: CGFloat = 16
        static let summarySpacing: CGFloat = 8
        static let timeRowSpacing: CGFloat = 14
        static let currentSessionProgressCaptionSpacing: CGFloat = 8
        static let summaryRowSpacing: CGFloat = 12
        static let summaryTitleRowSpacing: CGFloat = 8
        static let actionRowSpacing: CGFloat = 8

        static let shadowOpacity: Float = 0.08
        static let shadowRadius: CGFloat = 10
        static let shadowOffset = CGSize(width: 0, height: -1)
        static let progressTrackBorderWidth: CGFloat = 0.5
        static let valuePillBorderWidth: CGFloat = 1
        static let progressCornerRadius: CGFloat = 5
        static let valuePillCornerRadius: CGFloat = 12
    }

    enum Colors {
        static var popoverBackground: NSColor { .windowBackgroundColor }
        static var primaryText: NSColor { .labelColor }
        static var secondaryText: NSColor { .secondaryLabelColor }
        static var divider: NSColor { .separatorColor }
        static var iconTint: NSColor { .secondaryLabelColor }
        static var currentSessionValue: NSColor { .systemBlue }
        static var currentSessionAccentStart: NSColor { Tokens.Brand.accentStart }
        static var currentSessionAccentEnd: NSColor { Tokens.Brand.accentEnd }
        static var checkInAccent: NSColor { .systemGreen }
        static var progressTrackBackground: NSColor { .secondarySystemFill }
        static var progressTrackBorder: NSColor { .separatorColor }
        static var todayTimesBackground: NSColor { .quaternarySystemFill }
        static var valuePillBackground: NSColor { .controlBackgroundColor }
        static var valuePillBorder: NSColor { .separatorColor }
        static var shadow: NSColor { Tokens.Effects.cardShadow }
    }

    enum Typography {
        static var sectionTitle: NSFont { .systemFont(ofSize: 13, weight: .semibold) }
        static var secondary: NSFont { .systemFont(ofSize: 12) }
        static var dateTitle: NSFont { .systemFont(ofSize: 16, weight: .bold) }
        static var currentSessionValue: NSFont {
            .monospacedDigitSystemFont(ofSize: 56, weight: .regular)
        }
        static var rowValue: NSFont {
            .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        }
        static var summaryValue: NSFont { .systemFont(ofSize: 18, weight: .bold) }
        static var progressCaption: NSFont { .systemFont(ofSize: 11, weight: .semibold) }

        static var currentSessionTitleAttributes: [NSAttributedString.Key: Any] {
            [
                .kern: Metrics.currentSessionTitleKern,
                .font: progressCaption,
                .foregroundColor: Colors.secondaryText,
            ]
        }
    }
}
